# role: speedscope
class role::speedscope {
  include ::docker
  include ::speedscope

  system::role { 'speedscope':
    description => 'Speedscope service server'
  }
}
