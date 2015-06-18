Physijs.scripts.worker = 'lib/physijs_worker.js'

# textures
zombieTexture = THREE.ImageUtils.loadTexture 'res/zombie.jpeg', new THREE.UVMapping()
bulletTexture = THREE.ImageUtils.loadTexture 'res/crate.gif', new THREE.UVMapping()
grassTexture = THREE.ImageUtils.loadTexture 'res/grasslight-big.jpg'
crateTexture = THREE.ImageUtils.loadTexture 'res/crate.gif', new THREE.UVMapping()

# materials
zombieMaterial = Physijs.createMaterial new THREE.MeshPhongMaterial
  map: zombieTexture
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

# DOM
blocker = document.getElementById 'blocker'
instructions = document.getElementById 'instructions'

# logic
controls = null
time = Date.now()

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
      time = Date.now()
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

    if /Firefox/i.test navigator.userAgent
      fullScreenChange = (event) ->
        fullScreenElement = document.fullscreenElement or document.mozFullscreenElement or document.mozFullScreenElement
        if element is fullScreenElement
          document.removeEventListener 'fullscreenchange', fullScreenChange
          document.removeEventListener 'mozfullscreenchange', fullScreenChange
          element.requestPointerLock()

          document.addEventListener 'fullscreenchange', fullScreenChange
          document.addEventListener 'mozfullscreenchange', fullScreenChange

          element.requestFullscreen = element.requestFullscreen or element.mozRequestFullscreen or element.mozRequestFullScreen
          element.requestFullscreen
    else
      element.requestPointerLock()
  , false
else
  instructions.innerHTML = 'Your browser doesn\'t seem to support Pointer Lock API'



# initialize graphics and controls
camera = new THREE.PerspectiveCamera 75, window.innerWidth / window.innerHeight, 1, 1000

scene = new Physijs.Scene()
scene.fog = new THREE.Fog 0x000000, 0, 750
scene.setGravity new THREE.Vector3 0, -50, 0

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

controls = new THREE.PointerLockControls camera
scene.add controls.getObject()



# create basic geometry
grassGeometry = new THREE.PlaneGeometry 2000, 2000, 100, 100
grassGeometry.applyMatrix(new THREE.Matrix4().makeRotationX(-Math.PI / 2))

grassTexture.wrapS = THREE.RepeatWrapping
grassTexture.wrapT = THREE.RepeatWrapping
grassTexture.repeat.set 40, 40
grassMesh = new Physijs.PlaneMesh grassGeometry, grassMaterial, 0
scene.add grassMesh

crateMaterial.color.setHSL 0.75, 0.75, 0.87
crateGeometry = new THREE.BoxGeometry 20, 20, 20
arenaSize = 20
arena = []
for x in [0..arenaSize]
  arena.push []
  for z in [0..arenaSize]
    arena[x].push false
randomInt = (max) -> Math.floor(Math.random() * max)
while crates.length < 100
  x = randomInt 20
  z = randomInt 20
  continue if (x is 10) and (z is 10)
  if not arena[x][z]
    crateMesh = new Physijs.BoxMesh crateGeometry, crateMaterial, 200
    crateMesh.position.x = (x - 10) * 20
    crateMesh.position.y = 10
    crateMesh.position.z = (z - 10) * 20
    scene.add crateMesh
    crates.push crateMesh
    arena[x][z] = true



# create renderer and handle window resize event
renderer = new THREE.WebGLRenderer()
renderer.setSize window.innerWidth, window.innerHeight
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

  massMultiplier = 5
  bulletGeometry = new THREE.SphereGeometry 0.3
  bulletMesh = new Physijs.SphereMesh bulletGeometry, bulletMaterial, massMultiplier

  bulletDirection = new THREE.Vector3()
  controls.getDirection bulletDirection

  shooterPosition = controls.getObject().position
  bulletMesh.position.x = shooterPosition.x + bulletDirection.x
  bulletMesh.position.y = shooterPosition.y + bulletDirection.y
  bulletMesh.position.z = shooterPosition.z + bulletDirection.z
  scene.add bulletMesh

  bulletDirection.multiplyScalar(120 * massMultiplier)
  bulletMesh.applyCentralImpulse bulletDirection

  bulletMesh.addEventListener 'collision', (collider) ->
    if collider in zombies
      zombies = _.without zombies, collider
      scene.remove collider

  bullets.push
    mesh: bulletMesh
    ttl: 200
, false



updateBullets = ->
  newBullets = bullets
  for bullet in bullets
    bullet.ttl -= 1
    if bullet.ttl < 0
      scene.remove bullet.mesh
      newBullets = _.without newBullets, bullet
  bullets = newBullets

updateZombies = ->
  if zombies.length < 7
    zombieGeometry = new THREE.BoxGeometry 10, 10, 10
    zombieMesh = new Physijs.BoxMesh zombieGeometry, zombieMaterial, 10
    zombieMesh.material.size = THREE.DoubleSide
    loop
      x = randomInt 20
      z = randomInt 20
      zombieMesh.position.x = (x - 10) * 20
      zombieMesh.position.y = if arena[x][z] then 15 else 5
      zombieMesh.position.z = (z - 10) * 20
      vec = new THREE.Vector3
      vec.copy controls.getObject().position
      vec.sub zombieMesh.position
      break if vec.length() > 5
    zombieMesh.lookAt controls.getObject().position
    zombies.push zombieMesh
    scene.add zombieMesh

  for zombie in zombies
    zombie.lookAt controls.getObject().position
    factor = 10
    dir =
      x: (controls.getObject().position.x - zombie.position.x) / factor
      y: (controls.getObject().position.y - zombie.position.y) / factor * 5
      z: (controls.getObject().position.z - zombie.position.z) / factor
    zombie.setLinearVelocity(new THREE.Vector3 dir.x, dir.y, dir.z)

checkCollisions = ->
  controls.setOnObject no
  controls.setNorthToObject no
  controls.setSouthToObject no
  controls.setEastToObject no
  controls.setWestToObject no

  for d in [[0, 0], [-6, -6], [-6, 6], [6, -6], [6, 6]]
    raycasterFeet.ray.origin.copy controls.getObject().position
    raycasterFeet.ray.origin.x += d[0]
    raycasterFeet.ray.origin.z += d[1]
    raycasterFeet.ray.origin.y -= 10
    intersections = raycasterFeet.intersectObjects crates
    if intersections.length
      distance = intersections[0].distance
      if (distance > 0) and (distance < 10)
        controls.setOnObject yes
        break

  detectDirectedCollision = (caster, callback) ->
    caster.ray.origin.copy controls.getObject().position
    intersections = caster.intersectObjects crates
    if intersections.length
      distance = intersections[0].distance
      callback() if (distance > 0) and (distance < 6)
  detectDirectedCollision raycasterNorth, -> controls.setNorthToObject yes
  detectDirectedCollision raycasterSouth, -> controls.setSouthToObject yes
  detectDirectedCollision raycasterEast, -> controls.setEastToObject yes
  detectDirectedCollision raycasterWest, -> controls.setWestToObject yes



animate = ->
  requestAnimationFrame animate
  return if not controls.enabled

  delta = Date.now() - time
  controls.update delta
  time += delta

  updateBullets()
  updateZombies()
  checkCollisions()
  scene.simulate delta, 1



  renderer.render scene, camera



animate()
