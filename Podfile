platform :ios, '17.0'
install! 'cocoapods', :deterministic_uuids => true
project 'LocalFrame.xcodeproj'

target 'LocalFrame' do
  use_frameworks! :linkage => :static
  pod 'MobileVLCKit', '3.7.4'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    end
  end
end
