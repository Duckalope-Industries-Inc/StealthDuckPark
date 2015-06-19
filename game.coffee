Physijs.scripts.worker = 'lib/physijs_worker.js'

randomInt = (max) -> Math.floor(Math.random() * max)
randomFloat = (min, max) -> (Math.random() * (min + max)) - min

# show FPS
stats = new Stats()
stats.setMode(0)  # 0: fps, 1: ms

stats.domElement.style.position = 'absolute'
stats.domElement.style.left = '0px'
stats.domElement.style.top = '0px'

document.getElementById('Stats-output').appendChild stats.domElement


# augment three.js
THREE.Object3D.prototype.rotateAroundWorldAxis = (axis, radians) ->
  rotWorldMatrix = new THREE.Matrix4()
  rotWorldMatrix.makeRotationAxis axis.normalize(), radians
  rotWorldMatrix.multiply this.matrix
  this.matrix = rotWorldMatrix
  this.rotation.setFromRotationMatrix this.matrix

THREE.axis =
  x: new THREE.Vector3 1, 0, 0
  y: new THREE.Vector3 0, 1, 0
  z: new THREE.Vector3 0, 0, 1

deltaVector = (a, b) ->
  vec = new THREE.Vector3
  vec.copy b
  vec.sub a
  vec
distance = (a, b) ->
  deltaVector(a, b).length()

# textures
zombieTexture = THREE.ImageUtils.loadTexture 'res/zombie.png', new THREE.UVMapping()
bulletTexture = THREE.ImageUtils.loadTexture 'res/crate.gif', new THREE.UVMapping()
grassTexture = THREE.ImageUtils.loadTexture 'res/grasslight-big.jpg'
crateTexture = THREE.ImageUtils.loadTexture 'res/crate.gif', new THREE.UVMapping()
flareTexture = THREE.ImageUtils.loadTexture 'res/lensflare0.png'
moonTexture = THREE.ImageUtils.loadTexture 'res/moon.png'

# materials
zombieMaterialFactory = -> Physijs.createMaterial new THREE.MeshPhongMaterial
  map: zombieTexture
  transparent: yes
  shading: THREE.FlatShading
, 0, 0
bulletMaterial = Physijs.createMaterial new THREE.MeshLambertMaterial
  map: bulletTexture
  specular: 0xffffff
  shading: THREE.FlatShading
, 1, 1
grassMaterial = Physijs.createMaterial new THREE.MeshLambertMaterial
  map: grassTexture
  specular: 0xffffff
, 0.7, 0
crateMaterial = Physijs.createMaterial new THREE.MeshLambertMaterial
  map: crateTexture
  specular: 0xffffff
  shading: THREE.FlatShading
, 0.7, 0
moonMaterial = Physijs.createMaterial new THREE.MeshBasicMaterial
  map: moonTexture
  transparent: yes
  side: THREE.DoubleSide
, 1, 0

# models
lampModelDeferred = Deferred()
#lampLoader = new THREE.OBJLoader()
#lampLoader.load 'res/StreetLamp.obj', (geometry) -> lampModelDeferred.resolve geometry
lampLoader = new THREE.OBJMTLLoader()
lampLoader.load 'res/StreetLamp.obj', 'res/StreetLamp.mtl', (mesh) -> lampModelDeferred.resolve mesh

# DOM
blocker = document.getElementById 'blocker'
instructions = document.getElementById 'instructions'

# logic
controls = null
times =
  frame: Date.now()

crates = []
bullets = []
zombies = []



# pointer lock
hasPointerLock = 'pointerLockElement' of document or 'mozPointerLockElement' of document or 'webkitPointerLockElement' of document

if hasPointerLock
  element = document.body

  pointerLockChange = (event) ->
    pointerLockElement = document.pointerLockElement or document.mozPointerLockElement or document.webkitPointerLockElement
    if element is pointerLockElement
      now = Date.now()
      pauseDuration = now - times.frame
      for key of times
        times[key] += pauseDuration
      times.frame = now
      if pauseDuration
        for zombie in zombies
          zombie.anger.irritatedSince += pauseDuration
      controls.enabled = yes
      blocker.style.display = 'none'
    else
      controls.enabled = no
      blocker.style.display = '-webkit-box'
      blocker.style.display = '-moz-box'
      blocker.style.display = 'box'
      instructions.style.display = 'block'

  pointerLockError = (event) ->
    instructions.style.display = 'block'

  document.addEventListener 'pointerlockchange', pointerLockChange, false
  document.addEventListener 'mozpointerlockchange', pointerLockChange, false
  document.addEventListener 'webkitpointerlockchange', pointerLockChange, false

  document.addEventListener 'pointerlockerror', pointerLockError, false
  document.addEventListener 'mozpointerlockerror', pointerLockError, false
  document.addEventListener 'webkitpointerlockerror', pointerLockError, false

  instructions.addEventListener 'click', (event) ->
    instructions.style.display = 'none'

    element.requestPointerLock = element.requestPointerLock or element.mozRequestPointerLock or element.webkitRequestPointerLock
    element.requestFullscreen = element.requestFullscreen or element.mozRequestFullscreen or element.mozRequestFullScreen or element.webkitRequestFullscreen

    if element.requestFullscreen
      fullScreenChange = (event) ->
        fullScreenElement = document.fullscreenElement or document.mozFullscreenElement or document.mozFullScreenElement or document.webkitFullscreenElement
        if element is fullScreenElement
          element.requestPointerLock()

      document.addEventListener 'fullscreenchange', fullScreenChange
      document.addEventListener 'mozfullscreenchange', fullScreenChange
      document.addEventListener 'webkitfullscreenchange', fullScreenChange

      element.requestFullscreen()
    else
      element.requestPointerLock()
  , false
else
  instructions.innerHTML = 'Your browser doesn\'t seem to support Pointer Lock API'



# initialize graphics and controls
camera = new THREE.PerspectiveCamera 75, window.innerWidth / window.innerHeight, 1, 1000

scene = new Physijs.Scene()
scene.fog = new THREE.Fog 0x000000, 0, 750
scene.setGravity new THREE.Vector3 0, -100, 0

controls = new THREE.PointerLockControls camera
scene.add controls.getObject()



# create lighting
light1 = new THREE.DirectionalLight 0xffffff, 0.1
light1.position.set 1, 1, 1
scene.add light1

light2 = new THREE.DirectionalLight 0xffffff, 0.05
light2.position.set -1, -0.5, 1
scene.add light2

flashlight = new THREE.SpotLight 0xffffff, 1.4, 240
camera.add flashlight
flashlight.position.set 0, -1, 10
flashlight.target = camera

lampLight = new THREE.SpotLight 0xffffff, 2.2, 200
lampLight.position.set 16.5, 38, 0
lampLightTarget = new THREE.Object3D
lampLight.target = lampLightTarget
lampLightTarget.position.copy lampLight.position
lampLightTarget.position.y -= 1
lampLight.castShadow = yes
lampLight.shadowCameraNear = 1
lampLight.shadowCameraFar = 40
lampLight.shadowCameraFov = 175
lampLight.shadowMapWidth = 1536
lampLight.shadowMapHeight = 1536
#lampLight.shadowCameraVisible = yes  # use for adjusting FOV
scene.add lampLight

flareColor = new THREE.Color 0xffffff
flareColor.setHSL 0.08, 0.8, 1
lampFlare = new THREE.LensFlare flareTexture, 384, 0, THREE.AdditiveBlending, flareColor
lampFlare.position.set 16.5, 38, 0.01
scene.add lampFlare



# create basic geometry
grassGeometry = new THREE.PlaneGeometry 1000, 1000, 100, 100
grassGeometry.applyMatrix(new THREE.Matrix4().makeRotationX(-Math.PI / 2))
grassTexture.wrapS = THREE.RepeatWrapping
grassTexture.wrapT = THREE.RepeatWrapping
grassTexture.repeat.set 40, 40
grassMesh = new Physijs.PlaneMesh grassGeometry, grassMaterial, 0
grassMesh.receiveShadow = yes
scene.add grassMesh

crateMaterial.color.setHSL 0.75, 0.75, 0.87
crateGeometry = new THREE.BoxGeometry 20, 20, 20
# crates are created during rendering

lampModelDeferred.promise().then (geometry) ->
  lampMaterial = new THREE.MeshLambertMaterial
    color: 0xffffff
    transparent: yes
    opacity: 0

  lampGeometry = new THREE.CylinderGeometry 1, 1, 30, 8
  lampMesh = new Physijs.BoxMesh lampGeometry, lampMaterial, 0
  lampMesh.castShadow = yes
  lampMesh.scale.set 3, 3, 3
  lampMesh.position.set -5, 0, 0

  lampPartGeometry = new THREE.BoxGeometry 8, 1.5, 2.5
  lampPartMesh = new Physijs.BoxMesh lampPartGeometry, lampMaterial, 0
  lampPartMesh.position.set 5, 13.5, 0
  lampMesh.add lampPartMesh

  scene.add lampMesh
  lampMesh.add geometry

moonGeometry = new THREE.PlaneGeometry 30, 30
moonMesh = new Physijs.BoxMesh moonGeometry, moonMaterial, 0
moonMeshDelta = new THREE.Vector3 -60, 120, -180
scene.add moonMesh


# create renderer and handle window resize event
renderer = new THREE.WebGLRenderer alpha: yes
renderer.setSize window.innerWidth, window.innerHeight
renderer.shadowMapEnabled = yes
document.body.appendChild renderer.domElement

window.addEventListener 'resize', ->
  camera.aspect = window.innerWidth / window.innerHeight
  camera.updateProjectionMatrix()
  renderer.setSize window.innerWidth, window.innerHeight
, false



# initialize manual collision checking
raycasterForDirection = (x, y, z) ->
  caster = new THREE.Raycaster()
  caster.ray.direction.set x, y, z
  caster
raycasterFeet = raycasterForDirection 0, -1, 0
raycasterNorth = raycasterForDirection 0, 0, -1
raycasterSouth = raycasterForDirection 0, 0, 1
raycasterWest = raycasterForDirection -1, 0, 0
raycasterEast = raycasterForDirection 1, 0, 0



# handle mouse events
document.addEventListener 'mousedown', (event) ->
  event.preventDefault()

  bulletDirection = new THREE.Vector3()
  controls.getDirection bulletDirection

  shootBullet controls.getObject().position, null, bulletDirection
, false



# raycasting
raycastDownwards = (from) ->
  raycasterFeet.ray.origin.copy from
  raycasterFeet.ray.origin.y -= 10
  intersections = raycasterFeet.intersectObjects crates
  if intersections.length
    dist = intersections[0].distance
    if (dist > 0) and (dist < 10)
      return true
  return false

handleDirectedCollision = (caster, callback) ->
  caster.ray.origin.copy controls.getObject().position
  intersections = caster.intersectObjects crates
  if intersections.length
    dist = intersections[0].distance
    callback() if (dist > 0) and (dist < 6)



# zombies
max_health = 20
initial_health = 15
spawnZombie = ->
  zombieGeometry = new THREE.BoxGeometry 10, 10, 10
  zombieMesh = new Physijs.BoxMesh zombieGeometry, zombieMaterialFactory(), 10
  zombieMesh.material.size = THREE.DoubleSide
  zombieMesh.castShadow = yes

  loop
    x = (randomInt(20) - 10) * 20
    z = (randomInt(20) - 10) * 20
    vec = new THREE.Vector3 x, 25, z
    continue if raycastDownwards vec
    vec.sub controls.getObject().position
    vec.y = 0
    break if vec.length() > 100

  zombieMesh.position.x = x
  zombieMesh.position.y = 5
  zombieMesh.position.z = z
  zombieMesh.lookAt controls.getObject().position

  now = Date.now()

  zombieMesh.setHealth = (value, regenOffset = 0) ->
    @health = Math.max value, 0
    healthScaled = @health / max_health
    @material.color.setRGB 1, healthScaled, healthScaled
    @nextRegen = Date.now() + regenOffset
  zombieMesh.nextRegen = now
  zombieMesh.setHealth initial_health

  zombieMesh.anger =
    lastPosition: new THREE.Vector3
    irritatedSince: now
    clear: ->
      @lastPosition.copy zombieMesh.position
      @irritatedSince = Date.now()
    goMad: ->
      @clear()
      @irritatedSince += 2000
      for crate in crates
        vec = deltaVector zombieMesh.position, crate.position
        if vec.length() < 30
          vec.y = 50
          vec.multiplyScalar 300
          crate.applyCentralImpulse vec

  zombies.push zombieMesh
  scene.add zombieMesh

timeTillRegen = 2000
regenStep = 300
zombieWasHit = (zombie, bullet) ->
  zombie.setHealth(zombie.health - 5, timeTillRegen)
  if !zombie.health
    zombies = _.without zombies, zombie
    scene.remove zombie
  bullets = bullets.filter (item) -> item isnt bullet
  scene.remove bullet



# crates
addCrate = (pos) ->
  crateMesh = new Physijs.BoxMesh crateGeometry, crateMaterial, 200
  crateMesh.position.copy pos
  crateMesh.castShadow = yes
#  crateMesh.receiveShadow = yes  # -25% FPS ;)
  scene.add crateMesh
  crates.push crateMesh
  crateMesh



# bullets
shootBullet = (from, atPosition=null, inDirection=null, initialDistance=1) ->
  massMultiplier = 5
  bulletGeometry = new THREE.SphereGeometry 0.3
  bulletMesh = new Physijs.SphereMesh bulletGeometry, bulletMaterial, massMultiplier

  if atPosition
    direction = new THREE.Vector3
    direction.copy atPosition
    direction.sub from
  else
    direction = new THREE.Vector3
    direction.copy inDirection
  direction.normalize()

  boostedDirection = new THREE.Vector3
  boostedDirection.copy direction
  boostedDirection.multiplyScalar initialDistance
  bulletMesh.position.copy from
  bulletMesh.position.add boostedDirection
  scene.add bulletMesh

  direction.multiplyScalar(150 * massMultiplier)
  bulletMesh.applyCentralImpulse direction

  bulletMesh.ttl = 200
  bullets.push bulletMesh



# frame methods
checkCollisions = ->
  controls.setOnObject no
  controls.setNorthToObject no
  controls.setSouthToObject no
  controls.setEastToObject no
  controls.setWestToObject no

  if controls.getObject().position.y <= 10
    controls.setOnObject yes
  else
    for d in [[0, 0], [-6, -6], [-6, 6], [6, -6], [6, 6]]
      vec = new THREE.Vector3
      vec.copy controls.getObject().position
      vec.x += d[0]
      vec.z += d[1]
      if raycastDownwards vec
        controls.setOnObject yes
        break

  handleDirectedCollision raycasterNorth, -> controls.setNorthToObject yes
  handleDirectedCollision raycasterSouth, -> controls.setSouthToObject yes
  handleDirectedCollision raycasterEast, -> controls.setEastToObject yes
  handleDirectedCollision raycasterWest, -> controls.setWestToObject yes

updateBullets = ->
  newBullets = bullets
  for bullet in bullets
    bullet.ttl -= 1
    if bullet.ttl < 0
      scene.remove bullet
      newBullets = _.without newBullets, bullet
  bullets = newBullets

getRandomInt = (min, max) ->
    Math.floor(Math.random() * (max - min + 1)) + min

times.zombieSpawned = Date.now() + 3000  # delay initial spawn
updateZombies = (delta) ->
  if zombies.length < 9
    now = Date.now()
    if now - times.zombieSpawned > 1000  # do not spawn too frequently
      spawnZombie()
      times.zombieSpawned = now

  queue = []
  now = Date.now()
  for zombie in zombies
    zombie.lookAt controls.getObject().position
    factor = 10
    dir =
      x: (controls.getObject().position.x - zombie.position.x) / factor
      y: 0
      z: (controls.getObject().position.z - zombie.position.z) / factor
    zombie.setLinearVelocity(new THREE.Vector3 dir.x, dir.y, dir.z)

    if (zombie.health < max_health) and (zombie.nextRegen <= now)
      zombie.setHealth(zombie.health + 1, regenStep)

    posDelta = distance zombie.position, zombie.anger.lastPosition
    if posDelta / delta > 0.4
      zombie.anger.clear()
    else
      if now - zombie.anger.irritatedSince > 3000
        zombie.anger.goMad()

    for bullet in bullets
      if (distance zombie.position, bullet.position) < 8
        queue.push
          zombie: zombie
          bullet: bullet

    # zombies will shoot you now!
    if (getRandomInt 1, 95) % 94 == 1
      shootBullet zombie.position, controls.getObject().position, null, 10

  for pair in queue
    zombieWasHit pair.zombie, pair.bullet

times.crateSpawned = Date.now()
arenaSize = 400
updateCrates = ->
  if crates.length < 100
    now = Date.now()
    if now - times.crateSpawned > 50  # do not spawn too frequently
      x = randomInt arenaSize
      z = randomInt arenaSize
      position = new THREE.Vector3 x - arenaSize / 2, 100, z - arenaSize / 2
      pitch =
        x: randomFloat -Math.PI / 4, Math.PI / 4
        z: randomFloat -Math.PI / 4, Math.PI / 4
      yaw = randomFloat -Math.PI, Math.PI
      crate = addCrate position
      crate.rotateAroundWorldAxis THREE.axis.x, pitch.x
      crate.rotateAroundWorldAxis THREE.axis.y, yaw
      crate.rotateAroundWorldAxis THREE.axis.z, pitch.z
      crate.applyCentralImpulse new THREE.Vector3 0, -20000, 0
      times.crateSpawned = now

updateMoon = ->
  moonMesh.position.copy controls.getObject().position
  moonMesh.position.add moonMeshDelta
  moonMesh.lookAt controls.getObject().position




animate = ->
  requestAnimationFrame animate
  return if not controls.enabled

  delta = Date.now() - times.frame
  controls.update delta
  times.frame += delta

  updateBullets()
  updateZombies delta
  updateCrates()
  updateMoon()
  checkCollisions()

  scene.simulate delta, 1
  stats.update()

  renderer.render scene, camera



animate()
