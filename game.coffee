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
grassTexture = THREE.ImageUtils.loadTexture 'res/grasslight-big.jpg'
crateTexture = THREE.ImageUtils.loadTexture 'res/crate.gif', new THREE.UVMapping()
flareTexture = THREE.ImageUtils.loadTexture 'res/lensflare0.png'
moonTexture = THREE.ImageUtils.loadTexture 'res/moon.png'
fenceTexture = THREE.ImageUtils.loadTexture 'res/fence.png'
muzzleFlashTexture = THREE.ImageUtils.loadTexture 'res/muzzle_flash.png'
turretIconTexture = THREE.ImageUtils.loadTexture 'res/turret_icon.png'
laserTexture = THREE.ImageUtils.loadTexture 'res/laser.png'

# materials
transparentMaterial = new THREE.MeshLambertMaterial
  color: 0xffffff
  transparent: yes
  opacity: 0
transparentFrictionMaterial = Physijs.createMaterial new THREE.MeshLambertMaterial(
  color: 0xffffff
  transparent: yes
  opacity: 0
), 1, 0

zombieMaterialFactory = -> Physijs.createMaterial new THREE.MeshPhongMaterial(
  map: zombieTexture
  transparent: yes
  shading: THREE.FlatShading
  side: THREE.DoubleSide
), 0, 0
grassMaterial = Physijs.createMaterial new THREE.MeshLambertMaterial(
  map: grassTexture
  specular: 0xffffff
), 0.7, 0
crateMaterial = Physijs.createMaterial new THREE.MeshLambertMaterial(
  map: crateTexture
  specular: 0xffffff
  shading: THREE.FlatShading
), 0.7, 0
bulletMaterial = Physijs.createMaterial new THREE.MeshLambertMaterial(
  color: 0x222222
  specular: 0xffffff
), 0, 1

fenceMaterial = new THREE.MeshLambertMaterial
  map: fenceTexture
  specular: 0xffffff
moonMaterial = new THREE.MeshBasicMaterial
  map: moonTexture
  transparent: yes
  side: THREE.DoubleSide
moonMaterial.depthWrite = no
gunMaterial = new THREE.MeshLambertMaterial
  color: 0x222222
  specular: 0xffffff
muzzleFlashMaterialFactory = -> new THREE.MeshBasicMaterial
  map: muzzleFlashTexture
  specular: 0xffffff
  side: THREE.DoubleSide
  transparent: yes
  opacity: 0
turretMaterial = new THREE.MeshLambertMaterial
  color: 0x666666
  specular: 0xffffff
turretIconMaterial = new THREE.MeshBasicMaterial
  map: turretIconTexture
  side: THREE.DoubleSide
  transparent: yes
laserMaterial = new THREE.MeshBasicMaterial
  map: laserTexture
  side: THREE.DoubleSide
  transparent: yes
laserMaterial.blending = THREE.AdditiveBlending

# models
lampModelDeferred = Deferred()
lampLoader = new THREE.OBJMTLLoader()
lampLoader.load 'res/StreetLamp.obj', 'res/StreetLamp.mtl', (mesh) -> lampModelDeferred.resolve mesh

fenceModelDeferred = Deferred()
fenceLoader = new THREE.OBJLoader()
fenceLoader.load 'res/wall.obj', (geometry) -> fenceModelDeferred.resolve geometry

gunModelDeferred = Deferred()
gunLoader = new THREE.OBJLoader()
gunLoader.load 'res/ingram.obj', (geometry) -> gunModelDeferred.resolve geometry

turretModelDeferred = Deferred()
turretLoader = new THREE.OBJLoader()
turretLoader.load 'res/portalturret.obj', (geometry) -> turretModelDeferred.resolve geometry

parachuteModelDeferred = Deferred()
parachuteLoader = new THREE.OBJMTLLoader()
parachuteLoader.load 'res/Parachute.obj', 'res/Parachute.mtl', (geometry) -> parachuteModelDeferred.resolve geometry

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
fences = []
turrets = []



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

light3 = new THREE.DirectionalLight 0xffffff, 0.1
light3.position.set -0.5, 1, -1
scene.add light3

flashlight = new THREE.SpotLight 0xffffff, 1.4, 240
camera.add flashlight
flashlight.position.set 0, -1, 10
flashlight.target = camera

lampLight = new THREE.SpotLight 0xffffff, 2.2, 200
lampLight.position.set 23.5, 50, 0
lampLightTarget = new THREE.Object3D
lampLight.target = lampLightTarget
lampLightTarget.position.copy lampLight.position
lampLightTarget.position.y -= 1
lampLight.castShadow = yes
lampLight.shadowCameraNear = 1
lampLight.shadowCameraFar = 55
lampLight.shadowCameraFov = 173
lampLight.shadowMapWidth = 1536
lampLight.shadowMapHeight = 1536
#lampLight.shadowCameraVisible = yes  # use for adjusting FOV
scene.add lampLight

flareColor = new THREE.Color 0xffffff
flareColor.setHSL 0.08, 0.8, 1
lampFlare = new THREE.LensFlare flareTexture, 384, 0, THREE.AdditiveBlending, flareColor
lampFlare.position.copy lampLight.position
lampFlare.position.z += 0.01  # flares occasionally don't appear on 0 coordinates
scene.add lampFlare



# create basic geometry
fenceSize = 600
grassGeometry = new THREE.PlaneGeometry fenceSize, fenceSize, fenceSize / 10, fenceSize / 10
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

lampModelDeferred.promise().then (mesh) ->
  lampGeometry = new THREE.CylinderGeometry 1, 1, 30, 8
  lampMesh = new Physijs.BoxMesh lampGeometry, transparentMaterial, 0
  lampMesh.castShadow = yes
  lampMesh.scale.set 4, 4, 4
  lampMesh.position.set -5, 0, 0

  lampPartGeometry = new THREE.BoxGeometry 8, 1.5, 2.5
  lampPartMesh = new Physijs.BoxMesh lampPartGeometry, transparentMaterial, 0
  lampPartMesh.position.set 5, 13.5, 0
  lampMesh.add lampPartMesh

  scene.add lampMesh
  lampMesh.add mesh

fenceModelDeferred.promise().then (object) ->
  createFence = (position, rotation) ->
    fenceGeometry = new THREE.BoxGeometry fenceSize, 160, 4
    fenceMesh = new Physijs.BoxMesh fenceGeometry, transparentMaterial, 0
    fenceMesh.position.copy position
    fenceMesh.rotation.y = Math.PI / 2 * rotation

    fenceModelMesh = object.children[0].clone()
    fenceModelMesh.material = fenceMaterial
    fenceModelMesh.receiveShadow = yes
    fenceModelMesh.scale.set 56.5, 8, 15
    fenceModelMesh.position.x -= 29.5
    fenceModelMesh.position.y += 13
    fenceMesh.add fenceModelMesh

    scene.add fenceMesh
    fences.push fenceMesh
    fenceMesh
  createFence new THREE.Vector3(0, 0, -fenceSize / 2), 0
  createFence new THREE.Vector3(-fenceSize / 2, 0, 0), 1
  createFence new THREE.Vector3(0, 0, fenceSize / 2), 2
  createFence new THREE.Vector3(fenceSize / 2, 0, 0), 3

gunParentMesh =
  fire: ->
    return if not @children
    @acceleration = 0.05
    @children[0].position.z = 0.01
    @children[1].scale.set 1, 1, 1
    @children[1].material.opacity = 1
  update: (delta) ->
    @children[0].position.z -= @acceleration * 5
    if @children[0].position.z >= 0
      @acceleration = 0
      @children[0].position.z = 0.01
    else
      @acceleration -= delta / 1000
      return if not @children[1].material.opacity
    scale = @children[1].scale.x - (delta / 1000.0) * 8
    scale = Math.max 0.01, scale
    opacity = Math.sin scale * Math.PI / 2
    opacity = 0 if opacity < 0.05
    @children[1].scale.set scale, scale, scale
    @children[1].position.z = 5 + scale
    @children[1].material.opacity = opacity
gunModelDeferred.promise().then (object) ->
  _.extend gunParentMesh, object
  object.children[0].material = gunMaterial
  object.position.set 5, -3, -6
  object.rotation.x = Math.PI * 0.05
  object.rotation.y = Math.PI

  muzzleFlashGeometry = new THREE.PlaneGeometry 4, 4, 1, 1
  muzzleFlashMesh = new THREE.Mesh muzzleFlashGeometry, muzzleFlashMaterialFactory()
  muzzleFlashMesh.position.set 0.5, 1.5, 6
  muzzleFlashMesh.rotation.set Math.PI * 0.1, Math.PI * 0.25, Math.PI * 0.05
  object.add muzzleFlashMesh

  camera.add object
  
turretTemplate = null
parachuteTemplate = null
Deferred.all([turretModelDeferred.promise(), parachuteModelDeferred.promise()]).then (objects) ->
  [turretObject, parachuteObject] = objects

  turretTemplate = turretObject.children[0]
  turretTemplate.material = turretMaterial
  turretTemplate.scale.set 0.2, 0.2, 0.2
  turretTemplate.position.x -= 1
  turretTemplate.position.y -= 5.8
  turretTemplate.rotation.y = Math.PI / 2

  parachuteTemplate = parachuteObject
  parachuteTemplate.scale.set 3, 2, 3
  parachuteTemplate.position.set 1, 5, 0
# turrets are added during rendering

moonGeometry = new THREE.PlaneGeometry 30, 30
moonMesh = new THREE.Mesh moonGeometry, moonMaterial
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

  shootBullet controls.getObject().position, null, bulletDirection, 5
  gunParentMesh.fire()
, false



# raycasting
raycastDownwards = (from, halfHeight) ->
  raycasterFeet.ray.origin.copy from
  raycasterFeet.ray.origin.y -= halfHeight
  intersections = raycasterFeet.intersectObjects crates
  if intersections.length
    dist = intersections[0].distance
    if (dist > 0) and (dist < 10)
      return true
  return false

handleDirectedCollision = (caster, callback) ->
  caster.ray.origin.copy controls.getObject().position
  intersections = caster.intersectObjects(_.union crates, fences)
  if intersections.length
    dist = intersections[0].distance
    callback() if (dist > 0) and (dist < 6)



# zombies
spawnZombie = ->
  zombieGeometry = new THREE.BoxGeometry 10, 10, 10
  zombieMesh = new Physijs.BoxMesh zombieGeometry, zombieMaterialFactory(), 10
  zombieMesh.material.size = THREE.DoubleSide
  zombieMesh.castShadow = yes

  loop
    x = (randomInt(20) - 10) * 20
    z = (randomInt(20) - 10) * 20
    vec = new THREE.Vector3 x, 25, z
    continue if raycastDownwards vec, 5
    vec.sub controls.getObject().position
    vec.y = 0
    break if vec.length() > 100

  zombieMesh.position.x = x
  zombieMesh.position.y = 5
  zombieMesh.position.z = z
  zombieMesh.lookAt controls.getObject().position

  now = Date.now()

  zombieMesh.health =
    value: 1
    nextRegen: Date.now() + 2000
    set: (value, regenOffset = 0) ->
      @value = Math.max value, 0
      zombieMesh.material.color.setRGB 1, @value, @value
    hit: (v) ->
      @set @value - v
      @nextRegen = Date.now() + 2000
    regen: (v) ->
      @set @value + v
      @nextRegen = Date.now() + 300
    update: ->
      if (@value < 1) and (Date.now() > @nextRegen)
        @regen 0.1

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
          
  zombieMesh.victim =
    target: null
    attack: ->
      if not @target
        @target = controls.getObject()
      zombieMesh.lookAt @target.position
      factor = 10
      dir =
        x: (@target.position.x - zombieMesh.position.x) / factor
        y: 0
        z: (@target.position.z - zombieMesh.position.z) / factor
      zombieMesh.setLinearVelocity(new THREE.Vector3 dir.x, dir.y, dir.z)
      vector = deltaVector zombieMesh.position, @target.position
      if (vector.length() < 15) and @target.applyCentralImpulse
        vector.normalize()
        vector.y += 5
        vector.multiplyScalar 60
        @target.position.y += 0.1
        @target.applyCentralImpulse vector
    considerTarget: (potentialTarget) ->
      return if potentialTarget is @target
      oldDistance = distance zombieMesh.position, @target.position
      newDistance = distance zombieMesh.position, potentialTarget.position
      if (oldDistance > 5) and (newDistance < oldDistance - 3)
        @target = potentialTarget
      for zombie in _.without zombies, zombieMesh
        if distance(zombie.position, zombieMesh.position) < 45
          zombie.victim.considerTarget @target

  zombies.push zombieMesh
  scene.add zombieMesh

zombieHit = (shooter, zombie, bullet, damage) ->
  zombie.health.hit damage
  zombie.victim.considerTarget shooter
  if !zombie.health.value
    zombies = _.without zombies, zombie
    scene.remove zombie
  if bullet
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
  bulletGeometry = new THREE.SphereGeometry 0.2
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



# turrets
spawnTurret = (position, rotation) ->
  turretGeometry = new THREE.BoxGeometry 4, 12, 5.5
  turretMesh = new Physijs.BoxMesh turretGeometry, transparentFrictionMaterial, 10
  turretMesh.position.copy position
  turretMesh.rotation.y = rotation
  turretMesh.add turretTemplate.clone()

  turretBaseGeometry = new THREE.BoxGeometry 10, 2, 5.5
  turretBaseMesh = new Physijs.BoxMesh turretBaseGeometry, transparentFrictionMaterial, 40
  turretBaseMesh.position.set -1, -5, 0
  turretMesh.add turretBaseMesh

  parachuteMesh = parachuteTemplate.clone()
  turretMesh.add parachuteMesh
  turretMesh.parachute = parachuteMesh
  turretMesh.static =
    y: no
    timestamp: no

  turretMesh.knocked = no

  turretIconGeometry = new THREE.PlaneGeometry 10, 20, 1, 1
  turretIconMesh = new THREE.Mesh turretIconGeometry, turretIconMaterial
  turretMesh.icon = turretIconMesh

  turretLaserGeometry1 = new THREE.PlaneGeometry 1, 0.3, 1, 1
  turretLaserGeometry2 = new THREE.PlaneGeometry 1, 0.3, 1, 1
  turretLaserMesh1 = new THREE.Mesh turretLaserGeometry1, laserMaterial
  turretLaserMesh2 = new THREE.Mesh turretLaserGeometry2, laserMaterial
  turretLaserMesh1.add turretLaserMesh2
  turretLaserMesh2.rotation.x = Math.PI / 2
  turretLaserMesh1.position.x = 0.5

  turretLaserPivot = new THREE.Object3D
  turretLaserPivot.add turretLaserMesh1
  turretLaserPivot.position.y = 1.5
  turretMesh.laser =
    enabled: no
    mesh: turretLaserPivot
    fireTimestamp: 0
    lastIntensity: 1
    fired: no
    enable: ->
      @enabled = yes
      turretMesh.add @mesh
    disable: ->
      @wasEnabled = @enabled
      @enabled = no
      turretMesh.remove @mesh
    setLength: (l) ->
      @mesh.scale.x = l
    canFire: -> Date.now() - @fireTimestamp > 500
    fire: (callback) ->
      @fireCallback = callback
      @fireTimestamp = Date.now()
      @fired = no
    animate: ->
      progress = (Date.now() - @fireTimestamp) / 300.0 * Math.PI * 2
      if progress > Math.PI * 2
        @setIntensity 1
        return
      intensity = 1 + Math.sin progress
      if (intensity < @lastIntensity) and not @fired
        @fired = yes
        @fireCallback()
      @setIntensity intensity
    setIntensity: (v) ->
      v = Math.max 0.1, v
      @mesh.scale.y = v
      @mesh.scale.z = v
      @lastIntensity = v

  scene.add turretMesh
  turrets.push turretMesh
  turretMesh

getTilt = (object) ->
  deyaw = new THREE.Vector3
  deyaw.copy object.rotation
  deyaw.applyEuler new THREE.Euler 0, 0, 0, 'XYZ'
  deroll = new THREE.Vector3
  deroll.copy object.rotation
  deroll.applyEuler new THREE.Euler 0, 0, 0, 'XZY'
  x = Math.abs deyaw.x
  z = Math.abs deroll.z
  x: Math.min x, Math.PI - x
  z: Math.min z, Math.PI - z

turretIsKnocked = (turret) ->
  tilt = getTilt turret
  (tilt.x > Math.PI * 0.45) || (tilt.z > Math.PI * 0.3)



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
      if raycastDownwards vec, 10
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
    zombie.victim.attack()

    posDelta = distance zombie.position, zombie.anger.lastPosition
    if posDelta / delta > 0.4
      zombie.anger.clear()
    else
      if now - zombie.anger.irritatedSince > 3000
        zombie.anger.goMad()
    zombie.health.update()

    for bullet in bullets
      if (distance zombie.position, bullet.position) < 8
        queue.push
          zombie: zombie
          bullet: bullet

  for pair in queue
    zombieHit controls.getObject(), pair.zombie, pair.bullet, 0.25

times.crateSpawned = Date.now()
arenaSize = 400
updateCrates = ->
  if crates.length < 30
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

times.turretSpawned = Date.now()
updateTurrets = (delta) ->
  now = Date.now()
  if turrets.length < 6
    if now - times.turretSpawned > 3000  # do not spawn too frequently
      x = randomInt arenaSize
      z = randomInt arenaSize
      spawnTurret new THREE.Vector3(x - arenaSize / 2, 100, z - arenaSize / 2), randomFloat(0, Math.PI * 2)
      times.turretSpawned = now

  queue = []
  for turret in turrets
    if turret.knocked
      timeout = 2000
      fadeTime = 300
      if not turretIsKnocked turret
        turret.scale.set 1, 1, 1
        turret.knocked = no
        turret.laser.enable() if turret.laser.wasEnabled
      else if now - turret.knocked > timeout
        scale = Math.max(0.01, Math.cos (now - turret.knocked - timeout) / fadeTime * Math.PI / 2)
        turret.scale.set scale, scale, scale
        turret.icon.scale.set scale, scale, scale
        if now - turret.knocked > timeout + fadeTime
          queue.push turret
    else if turretIsKnocked turret
      turret.knocked = now
      turret.laser.disable()

    if not turret.static.timestamp
      if turret.static.y == turret.position.y
        turret.static.timestamp = now
      else
        turret.static.y = turret.position.y
    else
      if turret.static.y != turret.position.y
        turret.static.y = turret.position.y
        turret.static.timestamp = no
      else if now - turret.static.timestamp > 1000
        turret.static.removeParachute = yes

    if turret.parachute and not (turret in queue)
      if (not raycastDownwards(turret.position, 20)) and (turret.position.y > 20) and not turret.static.removeParachute
        velocity = turret.getLinearVelocity()
        velocity.y = -15
        turret.setLinearVelocity velocity
      else
        turret.remove turret.parachute
        turret.parachute = null
        scene.add turret.icon
        turret.icon.scale.set 0.01, 0.01, 0.01
        turret.laser.enable()

  for item in queue
    scene.remove item
    scene.remove item.icon
    turrets = _.without turrets, item

  for turret in turrets
    turret.icon.position.copy turret.position
    shift = Math.sin(now / 300.0) * 3
    turret.icon.position.y = 100 + shift
    directionVector = deltaVector controls.getObject().position, turret.position
    turret.icon.rotation.y = Math.atan2 directionVector.x, directionVector.z
    if turret.icon.scale.x < 1
      scale = Math.min 1, turret.icon.scale.x + delta / 300.0
      turret.icon.scale.set scale, scale, scale

    if not turret.parachute
      direction = new THREE.Vector3 1, 0, 0
      for axis in ['z', 'y', 'x']
        direction.applyAxisAngle THREE.axis[axis], turret.rotation[axis]
      raycaster = new THREE.Raycaster turret.position, direction
      intersections = raycaster.intersectObjects _.union crates, zombies, fences, turrets
      if intersections.length
        turret.laser.setLength intersections[0].distance
        if turret.laser.canFire() and (intersections[0].object in zombies)
          zombie = intersections[0].object
          firingTurret = turret
          turret.laser.fire -> zombieHit firingTurret, zombie, null, 0.2
      turret.laser.animate()

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
  updateTurrets delta
  updateZombies delta
  updateCrates()
  updateMoon()
  gunParentMesh.update delta
  checkCollisions()

  scene.simulate delta, 1
  stats.update()

  renderer.render scene, camera



animate()
