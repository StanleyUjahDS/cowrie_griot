import UserNotifications
import Intents

/// Adds a compact sender/conversation image to an incoming notification.
///
/// The service is deliberately conservative: it only downloads HTTPS image
/// URLs supplied by Griot, caps the response at 1.5 MB, and always delivers
/// the original notification if the attachment cannot be prepared.
final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let userInfo = request.content.userInfo
        let urlString = Self.imageURL(from: userInfo)
        guard let urlString, let url = URL(string: urlString) else {
            contentHandler(content)
            return
        }

        downloadImage(from: url) { [weak self] data, response in
            guard let self, let content = self.bestAttemptContent else {
                contentHandler(request.content)
                return
            }

            var deliveredContent: UNNotificationContent = content
            if let data,
               data.count <= Self.maxAttachmentBytes,
               Self.isImage(response: response, data: data),
               let attachment = Self.makeAttachment(data: data, identifier: request.identifier) {
                content.attachments = [attachment]
                // On iOS 15+, an INSendMessageIntent makes the notification
                // render as a communication notification: the sender avatar
                // is shown at the leading edge and iOS overlays Griot's app
                // identity automatically. If the intent cannot be built or
                // applied, the image attachment remains the safe fallback.
                if let intent = Self.messageIntent(userInfo: userInfo, body: content.body, imageData: data),
                   let updated = try? content.updating(from: intent) {
                    deliveredContent = updated
                }
            }
            contentHandler(deliveredContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let content = bestAttemptContent {
            contentHandler?(content)
        }
    }

    private func downloadImage(
        from url: URL,
        completion: @escaping (Data?, HTTPURLResponse?) -> Void
    ) {
        guard url.scheme?.lowercased() == "https" else {
            completion(nil, nil)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("image/*", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, _ in
            DispatchQueue.main.async {
                completion(data, response as? HTTPURLResponse)
            }
        }.resume()
    }

    private static func imageURL(from userInfo: [AnyHashable: Any]) -> String? {
        let keys = [
            "notificationAvatarUrl",
            "notification_avatar_url",
            "senderAvatarUrl",
            "sender_avatar_url",
            "senderAvatar",
            "sender_avatar",
            "senderProfileImageUrl",
            "sender_profile_image_url",
            "profileImageUrl",
            "profile_image_url",
            "avatarUrl",
            "avatar_url",
            "imageUrl",
            "image_url",
            "senderProfileUrl",
            "sender_profile_url",
            "conversationAvatarUrl",
            "conversation_avatar_url",
        ]

        func value(in dictionary: [AnyHashable: Any]) -> String? {
            for key in keys {
                if let value = dictionary[key] as? String,
                   value.lowercased().hasPrefix("https://") {
                    return value
                }
            }
            return nil
        }

        if let direct = value(in: userInfo) {
            return direct
        }
        if let nested = userInfo["data"] as? [AnyHashable: Any] {
            return value(in: nested)
        }
        if let nested = userInfo["data"] as? [String: Any] {
            return value(in: nested)
        }
        return nil
    }

    private static func messageIntent(
        userInfo: [AnyHashable: Any],
        body: String,
        imageData: Data
    ) -> INSendMessageIntent? {
        func stringValue(_ keys: [String]) -> String? {
            for key in keys {
                if let value = userInfo[key] as? String, !value.isEmpty {
                    return value
                }
                if let nested = userInfo["data"] as? [AnyHashable: Any],
                   let value = nested[key] as? String, !value.isEmpty {
                    return value
                }
                if let nested = userInfo["data"] as? [String: Any],
                   let value = nested[key] as? String, !value.isEmpty {
                    return value
                }
            }
            return nil
        }

        let senderName = stringValue(["senderName", "sender_name", "senderDisplayName", "sender_display_name", "actorName"]) ?? "Griot contact"
        let senderID = stringValue(["senderId", "sender_id", "actorId", "actor_id", "userId", "user_id"]) ?? senderName
        let conversationID = stringValue(["conversationId", "conversation_id", "chatId", "chat_id", "campfireId", "campfire_id"]) ?? senderID
        let handle = INPersonHandle(value: senderID, type: .unknown)
        let sender = INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: senderName,
            image: INImage(imageData: imageData),
            contactIdentifier: nil,
            customIdentifier: senderID
        )
        return INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: body,
            speakableGroupName: nil,
            conversationIdentifier: conversationID,
            serviceName: "Griot",
            sender: sender,
            attachments: nil
        )
    }

    private static let maxAttachmentBytes = 1_500_000

    private static func isImage(response: HTTPURLResponse?, data: Data) -> Bool {
        if let contentType = response?.value(forHTTPHeaderField: "Content-Type")?.lowercased() {
            return contentType.hasPrefix("image/")
        }
        // Keep a small fallback for object stores that omit Content-Type.
        return data.starts(with: [0xFF, 0xD8, 0xFF]) ||
            data.starts(with: [0x89, 0x50, 0x4E, 0x47]) ||
            data.starts(with: [0x47, 0x49, 0x46, 0x38]) ||
            data.starts(with: [0x52, 0x49, 0x46, 0x46])
    }

    private static func makeAttachment(data: Data, identifier: String) -> UNNotificationAttachment? {
        let directory = FileManager.default.temporaryDirectory
        let fileExtension: String
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            fileExtension = "jpg"
        } else if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            fileExtension = "png"
        } else if data.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            fileExtension = "gif"
        } else if data.starts(with: [0x52, 0x49, 0x46, 0x46]) {
            fileExtension = "webp"
        } else {
            fileExtension = "jpg"
        }
        let fileURL = directory.appendingPathComponent("griot-\(identifier).\(fileExtension)")
        do {
            try data.write(to: fileURL, options: .atomic)
            return try UNNotificationAttachment(
                identifier: "griot-avatar",
                url: fileURL,
                options: [UNNotificationAttachmentOptionsTypeHintKey: "public.image"]
            )
        } catch {
            return nil
        }
    }
}
