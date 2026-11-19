Pod::Spec.new do |s|
  s.name = 'ZegoExpressEngineExtension'
  s.version = '3.25.0'
  s.summary = 'ZEGO Express framework for the ReplayKit extension'
  s.description = 'ZEGO Express framework linkage for Griot screen sharing.'
  s.homepage = 'https://www.zegocloud.com/'
  s.author = { 'Griot' => 'info@griot.network' }
  s.license = { :type => 'Copyright' }
  s.source = { :git => 'https://github.com/zegoim/zego-express-flutter-sdk.git', :tag => '3.25.0' }
  s.platform = :ios, '15.5'
  s.vendored_frameworks = '.symlinks/plugins/zego_express_engine/ios/libs/*.xcframework'
end
