<?php

class autologin extends rcube_plugin {
  public $task = 'login';

  function init() {
    $this->add_hook('startup', array($this, 'startup'));
    $this->add_hook('authenticate', array($this, 'authenticate'));
  }

  function startup($args) {
    // change action to login
    if (empty($args['action']) && empty($_SESSION['user_id'])) {
      $args['action'] = 'login';
    }

    return $args;
  }

  function authenticate($args) {
    $args['user'] = 'vagrant';
    $args['pass'] = 'test';
    $args['host'] = 'localhost';
    $args['cookiecheck'] = false;
    $args['valid'] = true;

    return $args;
  }
}
