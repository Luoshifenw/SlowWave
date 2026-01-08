source 'https://cdn.cocoapods.org/'
source 'https://github.com/volcengine/volcengine-specs.git'

platform :ios, '13.0'

target 'SlowWave' do
  use_frameworks!

  # Volcano Engine Speech SDK
  pod 'SpeechEngineToB', '0.0.14.1-bugfix'
  
  # Networking
  pod 'SocketRocket', '0.6.1'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      config.build_settings['CLANG_WARN_NULLABILITY_COMPLETENESS'] = 'NO'
      config.build_settings['CLANG_WARN_STRICT_PROTOTYPES'] = 'NO'
      config.build_settings['GCC_TREAT_WARNINGS_AS_ERRORS'] = 'NO'
      config.build_settings['SWIFT_TREAT_WARNINGS_AS_ERRORS'] = 'NO'
    end
  end
end
