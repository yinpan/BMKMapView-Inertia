#
# Be sure to run `pod lib lint BMKMapView-Inertia.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'BMKMapView-Inertia'
  s.module_name      = 'BMKMapView_Inertia'
  s.version          = '0.1.0'
  s.summary          = 'The `BMKMapView-Inertia` is an extension of the `BMKMapView`.'
  
# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = 'The `BMKMapView-Inertia` is an extension of the `BMKMapView`.It can add inertia effect for the BaiduMap When zooming in or out.'

  s.homepage         = 'https://github.com/yinpan/BMKMapView-Inertia'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'yinpan' => 'yinpans@gmail.com' }
  s.source           = { :git => 'https://github.com/yinpan/BMKMapView-Inertia.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'
  
  s.platform         = :ios, '8.0'
  s.ios.deployment_target = '8.0'

  s.source_files = 'BMKMapView-Inertia/Classes/*.{swift,h}'
  
  # s.resource_bundles = {
  #   'BMKMapView-Inertia' => ['BMKMapView-Inertia/Assets/*.png']
  # }

  #s.public_header_files = 'Pod/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
   s.dependency 'BaiduMapKit', '~> 4.1.1' #百度地图SDK
   s.dependency 'Aspects'
   
   s.static_framework = true
   
   #-undefined dynamic_lookup 表示：当主工程和framework都包含同一个库时，会优先使用主工程的库。
   s.pod_target_xcconfig = {
       'OTHER_LDFLAGS'            => '$(inherited) -undefined dynamic_lookup -ObjC'
   }
   s.prepare_command = 'sh execute_modulemap.sh Example/Pods/BaiduMapKit'
   
end
