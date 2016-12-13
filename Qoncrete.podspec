Pod::Spec.new do |s|

  s.name         = "Qoncrete"
  s.version      = "0.0.2"
  s.summary      = "A tool for statistical data."
  s.description  = <<-DESC
                      Custom Analytics for Any Data Size.
                   DESC
  s.homepage     = "http://www.qoncrete.com"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author             = { "luowenqi" => "luo901211@gmail.com" }
  s.ios.deployment_target = "6.0"
  s.osx.deployment_target = "10.7"
  s.source       = { :git => "https://github.com/qoncrete/client-sdk-Objective-C.git", :tag => "#{s.version}" }
  s.source_files = '*.{h,m}'
  s.requires_arc = true

end
