# Uncomment the next line to define a global platform for your project
platform :ios, '12.0'

target 'CSAApp' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for CSAApp
  pod 'OpenCV', '~> 4.3.0'

  target 'CSAAppTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'CSAAppUITests' do
    # Pods for testing
  end

end

# OpenCVのNOマクロ衝突を回避するためのpost_installフック
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # iOS deploymentターゲットを12.0に更新
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      config.build_settings['OTHER_CPLUSPLUSFLAGS'] ||= ['']
      config.build_settings['OTHER_CPLUSPLUSFLAGS'] << '-DNO=CV_NO'
    end
  end
end
