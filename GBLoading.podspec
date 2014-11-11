Pod::Spec.new do |s|
  s.name         = 'GBLoading'
  s.version      = '2.3.0'
  s.summary      = 'An elegant, lightweight & most importantly robust asynchronous resource loading library for iOS.'
  s.homepage     = 'https://github.com/lmirosevic/GBLoading'
  s.license      = 'Apache License, Version 2.0'
  s.author       = { 'Luka Mirosevic' => 'luka@goonbee.com' }
  s.platform     = :ios, '5.0'
  s.source       = { git: 'https://github.com/lmirosevic/GBLoading.git', tag: s.version.to_s }
  s.source_files  = 'GBLoading/*.{h,m}'
  s.public_header_files = 'GBLoading/*.h'
  s.requires_arc = true

  s.dependency 'GBStorage', '~> 2.1'
end
