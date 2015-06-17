THREE.PointerLockControls = class
  pitchObject = new THREE.Object3D()
  yawObject = new THREE.Object3D()

  moveForward = no
  moveBackward = no
  moveLeft = no
  moveRight = no

  velocity = new THREE.Vector3()
  PI_2 = Math.PI / 2

  direction = new THREE.Vector3 0, 0, -1
  rotation = new THREE.Euler 0, 0, 0, 'YXZ'

  constructor: (camera) ->
    camera.rotation.set 0, 0, 0
    pitchObject.add camera

    yawObject.position.y = 10
    yawObject.add pitchObject

    document.addEventListener 'mousemove', (event) =>
      return null if not @enabled
      movementX = event.movementX or event.mozMovementX or event.webkitMovementX or 0
      movementY = event.movementY or event.mozMovementY or event.webkitMovementY or 0

      yawObject.rotation.y -= movementX * 0.002
      pitchObject.rotation.x -= movementY * 0.002
      pitchObject.rotation.x = Math.max -PI_2, Math.min(PI_2, pitchObject.rotation.x)
    , false

    document.addEventListener 'keydown', (event) ->
      switch event.keyCode
        when 38, 87  # up, w
          moveForward = yes
        when 37, 65  # left, a
          moveLeft = yes
        when 40, 83  # down, s
          moveBackward = yes
        when 39, 68  # right, d
          moveRight = yes
        when 32  # space
          if canJump
            velocity.y = 8
            canJump = no
    , false

    document.addEventListener 'keyup', (event) ->
      switch event.keyCode
        when 38, 87  # up, w
          moveForward = no
        when 37, 65  # left, a
          moveLeft = no
        when 40, 83  # down, s
          moveBackward = no
        when 39, 68  # right, d
          moveRight = no
    , false

    @enabled = no

  getObject: -> yawObject

  getDirection: (vec) ->
    rotation.set pitchObject.rotation.x, yawObject.rotation.y, 0
    vec.copy(direction).applyEuler rotation
    vec

  update: (delta) =>
    return null if not @enabled

    delta *= 0.1

    velocity.x += -velocity.x * 0.08 * delta
    velocity.y -= 0.25 * delta
    velocity.z += -velocity.z * 0.08 * delta

    if moveForward
      velocity.z -= 0.12 * delta
    if moveBackward
      velocity.z += 0.12 * delta
    if moveLeft
      velocity.x -= 0.12 * delta
    if moveRight
      velocity.x += 0.12 * delta

    yawObject.translateX velocity.x
    yawObject.translateZ velocity.z
