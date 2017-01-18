Pod::Spec.new do |spec|
  spec.name = "ReactiveSwiftRealm"
  spec.version = "0.0.1"
  spec.summary = "Add reactive swift functionality to Realm"
  spec.homepage = "https://github.com/bitomule/ReactiveSwiftRealm"
  spec.license = { type: 'MIT', file: 'LICENSE' }
  spec.authors = { "David Collado" => 'bitomule@gmail.com' }
  spec.social_media_url = "http://twitter.com/bitomule"

  spec.platform = :ios, "9.1"
  spec.requires_arc = true
  spec.source = { git: "https://github.com/bitomule/ReactiveSwiftRealm.git", tag: "#{spec.version}", submodules: true }
  spec.source_files = "ReactiveSwiftRealm/**/*.{h,swift}"

  spec.dependency "RealmSwift", "~> 2.2.0"
  spec.dependency "ReactiveSwift", "~> 1.0.0"
end