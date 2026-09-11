//
//  ShareViewController.swift
//  GriotShareExtension
//
//  Created by ujah stanley on 10/09/2026.
//

import Social
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {
    private let appGroup = "group.com.griotcowrie.griot_cowrie"

    override func isContentValid() -> Bool { true }

    override func didSelectPost() {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let item = items.first
        let providers = item?.attachments ?? []
        let payload: NSMutableDictionary = [
            "text": item?.attributedContentText?.string ?? "",
            "subject": item?.attributedTitle?.string ?? ""
        ]
        let work = DispatchGroup()

        if let provider = providers.first {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                work.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { value, _ in
                    if let url = value as? URL { payload["text"] = url.absoluteString }
                    work.leave()
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                work.enter()
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { value, _ in
                    if let text = value as? String { payload["text"] = text }
                    else if let text = value as? NSAttributedString { payload["text"] = text.string }
                    work.leave()
                }
            } else {
                let type: UTType = provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) ? .image : .movie
                if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                    work.enter()
                    provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { [weak self] url, _ in
                        if let url, let path = self?.copyToSharedContainer(url: url) {
                            payload["filePath"] = path
                            payload["mimeType"] = type == .image ? "image/*" : "video/*"
                        }
                        work.leave()
                    }
                }
            }
        }

        work.notify(queue: .main) { [weak self] in
            guard let self else { return }
            let defaults = UserDefaults(suiteName: self.appGroup)
            defaults?.set(payload as NSDictionary, forKey: "pending_shared_content")
            defaults?.synchronize()
            self.extensionContext?.open(URL(string: "griot://share")!) { _ in
                self.extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }

    private func copyToSharedContainer(url: URL) -> String? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else { return nil }
        let directory = container.appendingPathComponent("IncomingShares", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: url, to: destination)
            return destination.path
        } catch { return nil }
    }
}
