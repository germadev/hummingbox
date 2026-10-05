Pod::Spec.new do |s|
  s.name             = 'voicerecorder_native'
  s.version          = '1.0.0'
  s.summary          = 'Código nativo de la grabadora: conversión de audio y acceso a carpetas.'
  s.description      = <<-DESC
Conversión entre AAC (.m4a) y WAV con AVFoundation, acceso a carpetas elegidas
por el usuario y transcripción con el reconocimiento de voz del sistema.
                       DESC
  s.homepage         = 'https://github.com/germadev/voicerecorder'
  s.license          = { :type => 'Private' }
  s.author           = 'germadev'
  s.source           = { :path => '.' }
  s.source_files = 'voicerecorder_native/Sources/voicerecorder_native/**/*.swift'
  s.dependency 'Flutter'
  s.frameworks = 'AVFoundation', 'Speech'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
