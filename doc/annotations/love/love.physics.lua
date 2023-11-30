---@class love.physics
---Can simulate 2D rigid body physics in a realistic manner. This module is based on Box2D, and this API corresponds to the Box2D API as closely as possible.
local m = {}

-- region LoveBody
---@class LoveBody
---Bodies are objects with velocity and position.
local LoveBody = {}
---Applies an angular impulse to a body. This makes a single, instantaneous addition to the body momentum.
---
---A body with with a larger mass will react less. The reaction does '''not''' depend on the timestep, and is equivalent to applying a force continuously for 1 second. Impulses are best used to give a single push to a body. For a continuous push to a body it is better to use LoveBody:applyForce.
---@param impulse number @The impulse in kilogram-square meter per second.
function LoveBody:applyAngularImpulse(impulse)
end

---Apply force to a LoveBody.
---
---A force pushes a body in a direction. A body with with a larger mass will react less. The reaction also depends on how long a force is applied: since the force acts continuously over the entire timestep, a short timestep will only push the body for a short time. Thus forces are best used for many timesteps to give a continuous push to a body (like gravity). For a single push that is independent of timestep, it is better to use LoveBody:applyLinearImpulse.
---
---If the position to apply the force is not given, it will act on the center of mass of the body. The part of the force not directed towards the center of mass will cause the body to spin (and depends on the rotational inertia).
---
---Note that the force components and position must be given in world coordinates.
---@param fx number @The x component of force to apply to the center of mass.
---@param fy number @The y component of force to apply to the center of mass.
---@overload fun(fx:number, fy:number, x:number, y:number):void
function LoveBody:applyForce(fx, fy)
end

---Applies an impulse to a body.
---
---This makes a single, instantaneous addition to the body momentum.
---
---An impulse pushes a body in a direction. A body with with a larger mass will react less. The reaction does '''not''' depend on the timestep, and is equivalent to applying a force continuously for 1 second. Impulses are best used to give a single push to a body. For a continuous push to a body it is better to use LoveBody:applyForce.
---
---If the position to apply the impulse is not given, it will act on the center of mass of the body. The part of the impulse not directed towards the center of mass will cause the body to spin (and depends on the rotational inertia). 
---
---Note that the impulse components and position must be given in world coordinates.
---@param ix number @The x component of the impulse applied to the center of mass.
---@param iy number @The y component of the impulse applied to the center of mass.
---@overload fun(ix:number, iy:number, x:number, y:number):void
function LoveBody:applyLinearImpulse(ix, iy)
end

---Apply torque to a body.
---
---Torque is like a force that will change the angular velocity (spin) of a body. The effect will depend on the rotational inertia a body has.
---@param torque number @The torque to apply.
function LoveBody:applyTorque(torque)
end

---Explicitly destroys the LoveBody and all fixtures and joints attached to it.
---
---An error will occur if you attempt to use the object after calling this function. In 0.7.2, when you don't have time to wait for garbage collection, this function may be used to free the object immediately.
function LoveBody:destroy()
end

---Get the angle of the body.
---
---The angle is measured in radians. If you need to transform it to degrees, use math.deg.
---
---A value of 0 radians will mean 'looking to the right'. Although radians increase counter-clockwise, the y axis points down so it becomes ''clockwise'' from our point of view.
---@return number
function LoveBody:getAngle()
end

---Gets the Angular damping of the LoveBody
---
---The angular damping is the ''rate of decrease of the angular velocity over time'': A spinning body with no damping and no external forces will continue spinning indefinitely. A spinning body with damping will gradually stop spinning.
---
---Damping is not the same as friction - they can be modelled together. However, only damping is provided by Box2D (and LOVE).
---
---Damping parameters should be between 0 and infinity, with 0 meaning no damping, and infinity meaning full damping. Normally you will use a damping value between 0 and 0.1.
---@return number
function LoveBody:getAngularDamping()
end

---Get the angular velocity of the LoveBody.
---
---The angular velocity is the ''rate of change of angle over time''.
---
---It is changed in World:update by applying torques, off centre forces/impulses, and angular damping. It can be set directly with LoveBody:setAngularVelocity.
---
---If you need the ''rate of change of position over time'', use LoveBody:getLinearVelocity.
---@return number
function LoveBody:getAngularVelocity()
end

---Gets a list of all Contacts attached to the LoveBody.
---@return table
function LoveBody:getContacts()
end

---Returns a table with all fixtures.
---@return table
function LoveBody:getFixtures()
end

---Returns the gravity scale factor.
---@return number
function LoveBody:getGravityScale()
end

---Gets the rotational inertia of the body.
---
---The rotational inertia is how hard is it to make the body spin.
---@return number
function LoveBody:getInertia()
end

---Returns a table containing the Joints attached to this LoveBody.
---@return table
function LoveBody:getJoints()
end

---Gets the linear damping of the LoveBody.
---
---The linear damping is the ''rate of decrease of the linear velocity over time''. A moving body with no damping and no external forces will continue moving indefinitely, as is the case in space. A moving body with damping will gradually stop moving.
---
---Damping is not the same as friction - they can be modelled together.
---@return number
function LoveBody:getLinearDamping()
end

---Gets the linear velocity of the LoveBody from its center of mass.
---
---The linear velocity is the ''rate of change of position over time''.
---
---If you need the ''rate of change of angle over time'', use LoveBody:getAngularVelocity.
---
---If you need to get the linear velocity of a point different from the center of mass:
---
---*  LoveBody:getLinearVelocityFromLocalPoint allows you to specify the point in local coordinates.
---
---*  LoveBody:getLinearVelocityFromWorldPoint allows you to specify the point in world coordinates.
---
---See page 136 of 'Essential Mathematics for Games and Interactive Applications' for definitions of local and world coordinates.
---@return number, number
function LoveBody:getLinearVelocity()
end

---Get the linear velocity of a point on the body.
---
---The linear velocity for a point on the body is the velocity of the body center of mass plus the velocity at that point from the body spinning.
---
---The point on the body must given in local coordinates. Use LoveBody:getLinearVelocityFromWorldPoint to specify this with world coordinates.
---@param x number @The x position to measure velocity.
---@param y number @The y position to measure velocity.
---@return number, number
function LoveBody:getLinearVelocityFromLocalPoint(x, y)
end

---Get the linear velocity of a point on the body.
---
---The linear velocity for a point on the body is the velocity of the body center of mass plus the velocity at that point from the body spinning.
---
---The point on the body must given in world coordinates. Use LoveBody:getLinearVelocityFromLocalPoint to specify this with local coordinates.
---@param x number @The x position to measure velocity.
---@param y number @The y position to measure velocity.
---@return number, number
function LoveBody:getLinearVelocityFromWorldPoint(x, y)
end

---Get the center of mass position in local coordinates.
---
---Use LoveBody:getWorldCenter to get the center of mass in world coordinates.
---@return number, number
function LoveBody:getLocalCenter()
end

---LoveTransform a point from world coordinates to local coordinates.
---@param worldX number @The x position in world coordinates.
---@param worldY number @The y position in world coordinates.
---@return number, number
function LoveBody:getLocalPoint(worldX, worldY)
end

---LoveTransform a vector from world coordinates to local coordinates.
---@param worldX number @The vector x component in world coordinates.
---@param worldY number @The vector y component in world coordinates.
---@return number, number
function LoveBody:getLocalVector(worldX, worldY)
end

---Get the mass of the body.
---
---Static bodies always have a mass of 0.
---@return number
function LoveBody:getMass()
end

---Returns the mass, its center, and the rotational inertia.
---@return number, number, number, number
function LoveBody:getMassData()
end

---Get the position of the body.
---
---Note that this may not be the center of mass of the body.
---@return number, number
function LoveBody:getPosition()
end

---Get the position and angle of the body.
---
---Note that the position may not be the center of mass of the body. An angle of 0 radians will mean 'looking to the right'. Although radians increase counter-clockwise, the y axis points down so it becomes clockwise from our point of view.
---@return number, number, number
function LoveBody:getTransform()
end

---Returns the type of the body.
---@return BodyType
function LoveBody:getType()
end

---Returns the Lua value associated with this LoveBody.
---@return any
function LoveBody:getUserData()
end

---Gets the World the body lives in.
---@return World
function LoveBody:getWorld()
end

---Get the center of mass position in world coordinates.
---
---Use LoveBody:getLocalCenter to get the center of mass in local coordinates.
---@return number, number
function LoveBody:getWorldCenter()
end

---LoveTransform a point from local coordinates to world coordinates.
---@param localX number @The x position in local coordinates.
---@param localY number @The y position in local coordinates.
---@return number, number
function LoveBody:getWorldPoint(localX, localY)
end

---Transforms multiple points from local coordinates to world coordinates.
---@param x1 number @The x position of the first point.
---@param y1 number @The y position of the first point.
---@param x2 number @The x position of the second point.
---@param y2 number @The y position of the second point.
---@return number, number, number, number
function LoveBody:getWorldPoints(x1, y1, x2, y2)
end

---LoveTransform a vector from local coordinates to world coordinates.
---@param localX number @The vector x component in local coordinates.
---@param localY number @The vector y component in local coordinates.
---@return number, number
function LoveBody:getWorldVector(localX, localY)
end

---Get the x position of the body in world coordinates.
---@return number
function LoveBody:getX()
end

---Get the y position of the body in world coordinates.
---@return number
function LoveBody:getY()
end

---Returns whether the body is actively used in the simulation.
---@return boolean
function LoveBody:isActive()
end

---Returns the sleep status of the body.
---@return boolean
function LoveBody:isAwake()
end

---Get the bullet status of a body.
---
---There are two methods to check for body collisions:
---
---*  at their location when the world is updated (default)
---
---*  using continuous collision detection (CCD)
---
---The default method is efficient, but a body moving very quickly may sometimes jump over another body without producing a collision. A body that is set as a bullet will use CCD. This is less efficient, but is guaranteed not to jump when moving quickly.
---
---Note that static bodies (with zero mass) always use CCD, so your walls will not let a fast moving body pass through even if it is not a bullet.
---@return boolean
function LoveBody:isBullet()
end

---Gets whether the LoveBody is destroyed. Destroyed bodies cannot be used.
---@return boolean
function LoveBody:isDestroyed()
end

---Returns whether the body rotation is locked.
---@return boolean
function LoveBody:isFixedRotation()
end

---Returns the sleeping behaviour of the body.
---@return boolean
function LoveBody:isSleepingAllowed()
end

---Gets whether the LoveBody is touching the given other LoveBody.
---@param otherbody LoveBody @The other body to check.
---@return boolean
function LoveBody:isTouching(otherbody)
end

---Resets the mass of the body by recalculating it from the mass properties of the fixtures.
function LoveBody:resetMassData()
end

---Sets whether the body is active in the world.
---
---An inactive body does not take part in the simulation. It will not move or cause any collisions.
---@param active boolean @If the body is active or not.
function LoveBody:setActive(active)
end

---Set the angle of the body.
---
---The angle is measured in radians. If you need to transform it from degrees, use math.rad.
---
---A value of 0 radians will mean 'looking to the right'. Although radians increase counter-clockwise, the y axis points down so it becomes ''clockwise'' from our point of view.
---
---It is possible to cause a collision with another body by changing its angle. 
---@param angle number @The angle in radians.
function LoveBody:setAngle(angle)
end

---Sets the angular damping of a LoveBody
---
---See LoveBody:getAngularDamping for a definition of angular damping.
---
---Angular damping can take any value from 0 to infinity. It is recommended to stay between 0 and 0.1, though. Other values will look unrealistic.
---@param damping number @The new angular damping.
function LoveBody:setAngularDamping(damping)
end

---Sets the angular velocity of a LoveBody.
---
---The angular velocity is the ''rate of change of angle over time''.
---
---This function will not accumulate anything; any impulses previously applied since the last call to World:update will be lost. 
---@param w number @The new angular velocity, in radians per second
function LoveBody:setAngularVelocity(w)
end

---Wakes the body up or puts it to sleep.
---@param awake boolean @The body sleep status.
function LoveBody:setAwake(awake)
end

---Set the bullet status of a body.
---
---There are two methods to check for body collisions:
---
---*  at their location when the world is updated (default)
---
---*  using continuous collision detection (CCD)
---
---The default method is efficient, but a body moving very quickly may sometimes jump over another body without producing a collision. A body that is set as a bullet will use CCD. This is less efficient, but is guaranteed not to jump when moving quickly.
---
---Note that static bodies (with zero mass) always use CCD, so your walls will not let a fast moving body pass through even if it is not a bullet.
---@param status boolean @The bullet status of the body.
function LoveBody:setBullet(status)
end

---Set whether a body has fixed rotation.
---
---Bodies with fixed rotation don't vary the speed at which they rotate. Calling this function causes the mass to be reset. 
---@param isFixed boolean @Whether the body should have fixed rotation.
function LoveBody:setFixedRotation(isFixed)
end

---Sets a new gravity scale factor for the body.
---@param scale number @The new gravity scale factor.
function LoveBody:setGravityScale(scale)
end

---Set the inertia of a body.
---@param inertia number @The new moment of inertia, in kilograms * pixel squared.
function LoveBody:setInertia(inertia)
end

---Sets the linear damping of a LoveBody
---
---See LoveBody:getLinearDamping for a definition of linear damping.
---
---Linear damping can take any value from 0 to infinity. It is recommended to stay between 0 and 0.1, though. Other values will make the objects look 'floaty'(if gravity is enabled).
---@param ld number @The new linear damping
function LoveBody:setLinearDamping(ld)
end

---Sets a new linear velocity for the LoveBody.
---
---This function will not accumulate anything; any impulses previously applied since the last call to World:update will be lost.
---@param x number @The x-component of the velocity vector.
---@param y number @The y-component of the velocity vector.
function LoveBody:setLinearVelocity(x, y)
end

---Sets a new body mass.
---@param mass number @The mass, in kilograms.
function LoveBody:setMass(mass)
end

---Overrides the calculated mass data.
---@param x number @The x position of the center of mass.
---@param y number @The y position of the center of mass.
---@param mass number @The mass of the body.
---@param inertia number @The rotational inertia.
function LoveBody:setMassData(x, y, mass, inertia)
end

---Set the position of the body.
---
---Note that this may not be the center of mass of the body.
---
---This function cannot wake up the body.
---@param x number @The x position.
---@param y number @The y position.
function LoveBody:setPosition(x, y)
end

---Sets the sleeping behaviour of the body. Should sleeping be allowed, a body at rest will automatically sleep. A sleeping body is not simulated unless it collided with an awake body. Be wary that one can end up with a situation like a floating sleeping body if the floor was removed.
---@param allowed boolean @True if the body is allowed to sleep or false if not.
function LoveBody:setSleepingAllowed(allowed)
end

---Set the position and angle of the body.
---
---Note that the position may not be the center of mass of the body. An angle of 0 radians will mean 'looking to the right'. Although radians increase counter-clockwise, the y axis points down so it becomes clockwise from our point of view.
---
---This function cannot wake up the body.
---@param x number @The x component of the position.
---@param y number @The y component of the position.
---@param angle number @The angle in radians.
function LoveBody:setTransform(x, y, angle)
end

---Sets a new body type.
---@param type BodyType @The new type.
function LoveBody:setType(type)
end

---Associates a Lua value with the LoveBody.
---
---To delete the reference, explicitly pass nil.
---@param value any @The Lua value to associate with the LoveBody.
function LoveBody:setUserData(value)
end

---Set the x position of the body.
---
---This function cannot wake up the body. 
---@param x number @The x position.
function LoveBody:setX(x)
end

---Set the y position of the body.
---
---This function cannot wake up the body. 
---@param y number @The y position.
function LoveBody:setY(y)
end

-- endregion LoveBody
-- region LoveChainShape
---@class LoveChainShape
---A LoveChainShape consists of multiple line segments. It can be used to create the boundaries of your terrain. The shape does not have volume and can only collide with LovePolygonShape and LoveCircleShape.
---
---Unlike the LovePolygonShape, the LoveChainShape does not have a vertices limit or has to form a convex shape, but self intersections are not supported.
local LoveChainShape = {}
---Returns a child of the shape as an LoveEdgeShape.
---@param index number @The index of the child.
---@return LoveEdgeShape
function LoveChainShape:getChildEdge(index)
end

---Gets the vertex that establishes a connection to the next shape.
---
---Setting next and previous LoveChainShape vertices can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
---@return number, number
function LoveChainShape:getNextVertex()
end

---Returns a point of the shape.
---@param index number @The index of the point to return.
---@return number, number
function LoveChainShape:getPoint(index)
end

---Returns all points of the shape.
---@return number, number, number, number
function LoveChainShape:getPoints()
end

---Gets the vertex that establishes a connection to the previous shape.
---
---Setting next and previous LoveChainShape vertices can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
---@return number, number
function LoveChainShape:getPreviousVertex()
end

---Returns the number of vertices the shape has.
---@return number
function LoveChainShape:getVertexCount()
end

---Sets a vertex that establishes a connection to the next shape.
---
---This can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
---@param x number @The x-component of the vertex.
---@param y number @The y-component of the vertex.
function LoveChainShape:setNextVertex(x, y)
end

---Sets a vertex that establishes a connection to the previous shape.
---
---This can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
---@param x number @The x-component of the vertex.
---@param y number @The y-component of the vertex.
function LoveChainShape:setPreviousVertex(x, y)
end

-- endregion LoveChainShape
-- region LoveCircleShape
---@class LoveCircleShape
---Circle extends LoveShape and adds a radius and a local position.
local LoveCircleShape = {}
---Gets the center point of the circle shape.
---@return number, number
function LoveCircleShape:getPoint()
end

---Gets the radius of the circle shape.
---@return number
function LoveCircleShape:getRadius()
end

---Sets the location of the center of the circle shape.
---@param x number @The x-component of the new center point of the circle.
---@param y number @The y-component of the new center point of the circle.
function LoveCircleShape:setPoint(x, y)
end

---Sets the radius of the circle.
---@param radius number @The radius of the circle
function LoveCircleShape:setRadius(radius)
end

-- endregion LoveCircleShape
-- region LoveContact
---@class LoveContact
---Contacts are objects created to manage collisions in worlds.
local LoveContact = {}
---Gets the two Fixtures that hold the shapes that are in contact.
---@return LoveFixture, LoveFixture
function LoveContact:getFixtures()
end

---Get the friction between two shapes that are in contact.
---@return number
function LoveContact:getFriction()
end

---Get the normal vector between two shapes that are in contact.
---
---This function returns the coordinates of a unit vector that points from the first shape to the second.
---@return number, number
function LoveContact:getNormal()
end

---Returns the contact points of the two colliding fixtures. There can be one or two points.
---@return number, number, number, number
function LoveContact:getPositions()
end

---Get the restitution between two shapes that are in contact.
---@return number
function LoveContact:getRestitution()
end

---Returns whether the contact is enabled. The collision will be ignored if a contact gets disabled in the preSolve callback.
---@return boolean
function LoveContact:isEnabled()
end

---Returns whether the two colliding fixtures are touching each other.
---@return boolean
function LoveContact:isTouching()
end

---Resets the contact friction to the mixture value of both fixtures.
function LoveContact:resetFriction()
end

---Resets the contact restitution to the mixture value of both fixtures.
function LoveContact:resetRestitution()
end

---Enables or disables the contact.
---@param enabled boolean @True to enable or false to disable.
function LoveContact:setEnabled(enabled)
end

---Sets the contact friction.
---@param friction number @The contact friction.
function LoveContact:setFriction(friction)
end

---Sets the contact restitution.
---@param restitution number @The contact restitution.
function LoveContact:setRestitution(restitution)
end

-- endregion LoveContact
-- region LoveDistanceJoint
---@class LoveDistanceJoint
---Keeps two bodies at the same distance.
local LoveDistanceJoint = {}
---Gets the damping ratio.
---@return number
function LoveDistanceJoint:getDampingRatio()
end

---Gets the response speed.
---@return number
function LoveDistanceJoint:getFrequency()
end

---Gets the equilibrium distance between the two Bodies.
---@return number
function LoveDistanceJoint:getLength()
end

---Sets the damping ratio.
---@param ratio number @The damping ratio.
function LoveDistanceJoint:setDampingRatio(ratio)
end

---Sets the response speed.
---@param Hz number @The response speed.
function LoveDistanceJoint:setFrequency(Hz)
end

---Sets the equilibrium distance between the two Bodies.
---@param l number @The length between the two Bodies.
function LoveDistanceJoint:setLength(l)
end

-- endregion LoveDistanceJoint
-- region LoveEdgeShape
---@class LoveEdgeShape
---A LoveEdgeShape is a line segment. They can be used to create the boundaries of your terrain. The shape does not have volume and can only collide with LovePolygonShape and LoveCircleShape.
local LoveEdgeShape = {}
---Gets the vertex that establishes a connection to the next shape.
---
---Setting next and previous LoveEdgeShape vertices can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
---@return number, number
function LoveEdgeShape:getNextVertex()
end

---Returns the local coordinates of the edge points.
---@return number, number, number, number
function LoveEdgeShape:getPoints()
end

---Gets the vertex that establishes a connection to the previous shape.
---
---Setting next and previous LoveEdgeShape vertices can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
---@return number, number
function LoveEdgeShape:getPreviousVertex()
end

---Sets a vertex that establishes a connection to the next shape.
---
---This can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
---@param x number @The x-component of the vertex.
---@param y number @The y-component of the vertex.
function LoveEdgeShape:setNextVertex(x, y)
end

---Sets a vertex that establishes a connection to the previous shape.
---
---This can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
---@param x number @The x-component of the vertex.
---@param y number @The y-component of the vertex.
function LoveEdgeShape:setPreviousVertex(x, y)
end

-- endregion LoveEdgeShape
-- region LoveFixture
---@class LoveFixture
---Fixtures attach shapes to bodies.
local LoveFixture = {}
---Destroys the fixture.
function LoveFixture:destroy()
end

---Returns the body to which the fixture is attached.
---@return LoveBody
function LoveFixture:getBody()
end

---Returns the points of the fixture bounding box. In case the fixture has multiple children a 1-based index can be specified. For example, a fixture will have multiple children with a chain shape.
---@param index number @A bounding box of the fixture.
---@return number, number, number, number
function LoveFixture:getBoundingBox(index)
end

---Returns the categories the fixture belongs to.
---@return number, number
function LoveFixture:getCategory()
end

---Returns the density of the fixture.
---@return number
function LoveFixture:getDensity()
end

---Returns the filter data of the fixture.
---
---Categories and masks are encoded as the bits of a 16-bit integer.
---@return number, number, number
function LoveFixture:getFilterData()
end

---Returns the friction of the fixture.
---@return number
function LoveFixture:getFriction()
end

---Returns the group the fixture belongs to. Fixtures with the same group will always collide if the group is positive or never collide if it's negative. The group zero means no group.
---
---The groups range from -32768 to 32767.
---@return number
function LoveFixture:getGroupIndex()
end

---Returns which categories this fixture should '''NOT''' collide with.
---@return number, number
function LoveFixture:getMask()
end

---Returns the mass, its center and the rotational inertia.
---@return number, number, number, number
function LoveFixture:getMassData()
end

---Returns the restitution of the fixture.
---@return number
function LoveFixture:getRestitution()
end

---Returns the shape of the fixture. This shape is a reference to the actual data used in the simulation. It's possible to change its values between timesteps.
---@return LoveShape
function LoveFixture:getShape()
end

---Returns the Lua value associated with this fixture.
---@return any
function LoveFixture:getUserData()
end

---Gets whether the LoveFixture is destroyed. Destroyed fixtures cannot be used.
---@return boolean
function LoveFixture:isDestroyed()
end

---Returns whether the fixture is a sensor.
---@return boolean
function LoveFixture:isSensor()
end

---Casts a ray against the shape of the fixture and returns the surface normal vector and the line position where the ray hit. If the ray missed the shape, nil will be returned.
---
---The ray starts on the first point of the input line and goes towards the second point of the line. The fifth argument is the maximum distance the ray is going to travel as a scale factor of the input line length.
---
---The childIndex parameter is used to specify which child of a parent shape, such as a LoveChainShape, will be ray casted. For ChainShapes, the index of 1 is the first edge on the chain. Ray casting a parent shape will only test the child specified so if you want to test every shape of the parent, you must loop through all of its children.
---
---The world position of the impact can be calculated by multiplying the line vector with the third return value and adding it to the line starting point.
---
---hitx, hity = x1 + (x2 - x1) * fraction, y1 + (y2 - y1) * fraction
---@param x1 number @The x position of the input line starting point.
---@param y1 number @The y position of the input line starting point.
---@param x2 number @The x position of the input line end point.
---@param y2 number @The y position of the input line end point.
---@param maxFraction number @Ray length parameter.
---@param childIndex number @The index of the child the ray gets cast against.
---@return number, number, number
function LoveFixture:rayCast(x1, y1, x2, y2, maxFraction, childIndex)
end

---Sets the categories the fixture belongs to. There can be up to 16 categories represented as a number from 1 to 16.
---
---All fixture's default category is 1.
---@param category1 number @The first category.
---@param category2 number @The second category.
function LoveFixture:setCategory(category1, category2)
end

---Sets the density of the fixture. Call LoveBody:resetMassData if this needs to take effect immediately.
---@param density number @The fixture density in kilograms per square meter.
function LoveFixture:setDensity(density)
end

---Sets the filter data of the fixture.
---
---Groups, categories, and mask can be used to define the collision behaviour of the fixture.
---
---If two fixtures are in the same group they either always collide if the group is positive, or never collide if it's negative. If the group is zero or they do not match, then the contact filter checks if the fixtures select a category of the other fixture with their masks. The fixtures do not collide if that's not the case. If they do have each other's categories selected, the return value of the custom contact filter will be used. They always collide if none was set.
---
---There can be up to 16 categories. Categories and masks are encoded as the bits of a 16-bit integer.
---
---When created, prior to calling this function, all fixtures have category set to 1, mask set to 65535 (all categories) and group set to 0.
---
---This function allows setting all filter data for a fixture at once. To set only the categories, the mask or the group, you can use LoveFixture:setCategory, LoveFixture:setMask or LoveFixture:setGroupIndex respectively.
---@param categories number @The categories as an integer from 0 to 65535.
---@param mask number @The mask as an integer from 0 to 65535.
---@param group number @The group as an integer from -32768 to 32767.
function LoveFixture:setFilterData(categories, mask, group)
end

---Sets the friction of the fixture.
---
---Friction determines how shapes react when they 'slide' along other shapes. Low friction indicates a slippery surface, like ice, while high friction indicates a rough surface, like concrete. Range: 0.0 - 1.0.
---@param friction number @The fixture friction.
function LoveFixture:setFriction(friction)
end

---Sets the group the fixture belongs to. Fixtures with the same group will always collide if the group is positive or never collide if it's negative. The group zero means no group.
---
---The groups range from -32768 to 32767.
---@param group number @The group as an integer from -32768 to 32767.
function LoveFixture:setGroupIndex(group)
end

---Sets the category mask of the fixture. There can be up to 16 categories represented as a number from 1 to 16.
---
---This fixture will '''NOT''' collide with the fixtures that are in the selected categories if the other fixture also has a category of this fixture selected.
---@param mask1 number @The first category.
---@param mask2 number @The second category.
function LoveFixture:setMask(mask1, mask2)
end

---Sets the restitution of the fixture.
---@param restitution number @The fixture restitution.
function LoveFixture:setRestitution(restitution)
end

---Sets whether the fixture should act as a sensor.
---
---Sensors do not cause collision responses, but the begin-contact and end-contact World callbacks will still be called for this fixture.
---@param sensor boolean @The sensor status.
function LoveFixture:setSensor(sensor)
end

---Associates a Lua value with the fixture.
---
---To delete the reference, explicitly pass nil.
---@param value any @The Lua value to associate with the fixture.
function LoveFixture:setUserData(value)
end

---Checks if a point is inside the shape of the fixture.
---@param x number @The x position of the point.
---@param y number @The y position of the point.
---@return boolean
function LoveFixture:testPoint(x, y)
end

-- endregion LoveFixture
-- region LoveFrictionJoint
---@class LoveFrictionJoint
---A LoveFrictionJoint applies friction to a body.
local LoveFrictionJoint = {}
---Gets the maximum friction force in Newtons.
---@return number
function LoveFrictionJoint:getMaxForce()
end

---Gets the maximum friction torque in Newton-meters.
---@return number
function LoveFrictionJoint:getMaxTorque()
end

---Sets the maximum friction force in Newtons.
---@param maxForce number @Max force in Newtons.
function LoveFrictionJoint:setMaxForce(maxForce)
end

---Sets the maximum friction torque in Newton-meters.
---@param torque number @Maximum torque in Newton-meters.
function LoveFrictionJoint:setMaxTorque(torque)
end

-- endregion LoveFrictionJoint
-- region LoveGearJoint
---@class LoveGearJoint
---Keeps bodies together in such a way that they act like gears.
local LoveGearJoint = {}
---Get the Joints connected by this LoveGearJoint.
---@return LoveJoint, LoveJoint
function LoveGearJoint:getJoints()
end

---Get the ratio of a gear joint.
---@return number
function LoveGearJoint:getRatio()
end

---Set the ratio of a gear joint.
---@param ratio number @The new ratio of the joint.
function LoveGearJoint:setRatio(ratio)
end

-- endregion LoveGearJoint
-- region LoveJoint
---@class LoveJoint
---Attach multiple bodies together to interact in unique ways.
local LoveJoint = {}
---Explicitly destroys the LoveJoint. An error will occur if you attempt to use the object after calling this function.
---
---In 0.7.2, when you don't have time to wait for garbage collection, this function 
---
---may be used to free the object immediately.
function LoveJoint:destroy()
end

---Get the anchor points of the joint.
---@return number, number, number, number
function LoveJoint:getAnchors()
end

---Gets the bodies that the LoveJoint is attached to.
---@return LoveBody, LoveBody
function LoveJoint:getBodies()
end

---Gets whether the connected Bodies collide.
---@return boolean
function LoveJoint:getCollideConnected()
end

---Returns the reaction force in newtons on the second body
---@param x number @How long the force applies. Usually the inverse time step or 1/dt.
---@return number, number
function LoveJoint:getReactionForce(x)
end

---Returns the reaction torque on the second body.
---@param invdt number @How long the force applies. Usually the inverse time step or 1/dt.
---@return number
function LoveJoint:getReactionTorque(invdt)
end

---Gets a string representing the type.
---@return JointType
function LoveJoint:getType()
end

---Returns the Lua value associated with this LoveJoint.
---@return any
function LoveJoint:getUserData()
end

---Gets whether the LoveJoint is destroyed. Destroyed joints cannot be used.
---@return boolean
function LoveJoint:isDestroyed()
end

---Associates a Lua value with the LoveJoint.
---
---To delete the reference, explicitly pass nil.
---@param value any @The Lua value to associate with the LoveJoint.
function LoveJoint:setUserData(value)
end

-- endregion LoveJoint
-- region LoveMotorJoint
---@class LoveMotorJoint
---Controls the relative motion between two Bodies. Position and rotation offsets can be specified, as well as the maximum motor force and torque that will be applied to reach the target offsets.
local LoveMotorJoint = {}
---Gets the target angular offset between the two Bodies the LoveJoint is attached to.
---@return number
function LoveMotorJoint:getAngularOffset()
end

---Gets the target linear offset between the two Bodies the LoveJoint is attached to.
---@return number, number
function LoveMotorJoint:getLinearOffset()
end

---Sets the target angluar offset between the two Bodies the LoveJoint is attached to.
---@param angleoffset number @The target angular offset in radians: the second body's angle minus the first body's angle.
function LoveMotorJoint:setAngularOffset(angleoffset)
end

---Sets the target linear offset between the two Bodies the LoveJoint is attached to.
---@param x number @The x component of the target linear offset, relative to the first LoveBody.
---@param y number @The y component of the target linear offset, relative to the first LoveBody.
function LoveMotorJoint:setLinearOffset(x, y)
end

-- endregion LoveMotorJoint
-- region LoveMouseJoint
---@class LoveMouseJoint
---For controlling objects with the mouse.
local LoveMouseJoint = {}
---Returns the damping ratio.
---@return number
function LoveMouseJoint:getDampingRatio()
end

---Returns the frequency.
---@return number
function LoveMouseJoint:getFrequency()
end

---Gets the highest allowed force.
---@return number
function LoveMouseJoint:getMaxForce()
end

---Gets the target point.
---@return number, number
function LoveMouseJoint:getTarget()
end

---Sets a new damping ratio.
---@param ratio number @The new damping ratio.
function LoveMouseJoint:setDampingRatio(ratio)
end

---Sets a new frequency.
---@param freq number @The new frequency in hertz.
function LoveMouseJoint:setFrequency(freq)
end

---Sets the highest allowed force.
---@param f number @The max allowed force.
function LoveMouseJoint:setMaxForce(f)
end

---Sets the target point.
---@param x number @The x-component of the target.
---@param y number @The y-component of the target.
function LoveMouseJoint:setTarget(x, y)
end

-- endregion LoveMouseJoint
-- region LovePolygonShape
---@class LovePolygonShape
---A LovePolygonShape is a convex polygon with up to 8 vertices.
local LovePolygonShape = {}
---Get the local coordinates of the polygon's vertices.
---
---This function has a variable number of return values. It can be used in a nested fashion with love.graphics.polygon.
---@return number, number, number, number
function LovePolygonShape:getPoints()
end

-- endregion LovePolygonShape
-- region LovePrismaticJoint
---@class LovePrismaticJoint
---Restricts relative motion between Bodies to one shared axis.
local LovePrismaticJoint = {}
---Checks whether the limits are enabled.
---@return boolean
function LovePrismaticJoint:areLimitsEnabled()
end

---Gets the world-space axis vector of the Prismatic LoveJoint.
---@return number, number
function LovePrismaticJoint:getAxis()
end

---Get the current joint angle speed.
---@return number
function LovePrismaticJoint:getJointSpeed()
end

---Get the current joint translation.
---@return number
function LovePrismaticJoint:getJointTranslation()
end

---Gets the joint limits.
---@return number, number
function LovePrismaticJoint:getLimits()
end

---Gets the lower limit.
---@return number
function LovePrismaticJoint:getLowerLimit()
end

---Gets the maximum motor force.
---@return number
function LovePrismaticJoint:getMaxMotorForce()
end

---Returns the current motor force.
---@param invdt number @How long the force applies. Usually the inverse time step or 1/dt.
---@return number
function LovePrismaticJoint:getMotorForce(invdt)
end

---Gets the motor speed.
---@return number
function LovePrismaticJoint:getMotorSpeed()
end

---Gets the upper limit.
---@return number
function LovePrismaticJoint:getUpperLimit()
end

---Checks whether the motor is enabled.
---@return boolean
function LovePrismaticJoint:isMotorEnabled()
end

---Sets the limits.
---@param lower number @The lower limit, usually in meters.
---@param upper number @The upper limit, usually in meters.
function LovePrismaticJoint:setLimits(lower, upper)
end

---Enables/disables the joint limit.
---@return boolean
function LovePrismaticJoint:setLimitsEnabled()
end

---Sets the lower limit.
---@param lower number @The lower limit, usually in meters.
function LovePrismaticJoint:setLowerLimit(lower)
end

---Set the maximum motor force.
---@param f number @The maximum motor force, usually in N.
function LovePrismaticJoint:setMaxMotorForce(f)
end

---Enables/disables the joint motor.
---@param enable boolean @True to enable, false to disable.
function LovePrismaticJoint:setMotorEnabled(enable)
end

---Sets the motor speed.
---@param s number @The motor speed, usually in meters per second.
function LovePrismaticJoint:setMotorSpeed(s)
end

---Sets the upper limit.
---@param upper number @The upper limit, usually in meters.
function LovePrismaticJoint:setUpperLimit(upper)
end

-- endregion LovePrismaticJoint
-- region LovePulleyJoint
---@class LovePulleyJoint
---Allows you to simulate bodies connected through pulleys.
local LovePulleyJoint = {}
---Get the total length of the rope.
---@return number
function LovePulleyJoint:getConstant()
end

---Get the ground anchor positions in world coordinates.
---@return number, number, number, number
function LovePulleyJoint:getGroundAnchors()
end

---Get the current length of the rope segment attached to the first body.
---@return number
function LovePulleyJoint:getLengthA()
end

---Get the current length of the rope segment attached to the second body.
---@return number
function LovePulleyJoint:getLengthB()
end

---Get the maximum lengths of the rope segments.
---@return number, number
function LovePulleyJoint:getMaxLengths()
end

---Get the pulley ratio.
---@return number
function LovePulleyJoint:getRatio()
end

---Set the total length of the rope.
---
---Setting a new length for the rope updates the maximum length values of the joint.
---@param length number @The new length of the rope in the joint.
function LovePulleyJoint:setConstant(length)
end

---Set the maximum lengths of the rope segments.
---
---The physics module also imposes maximum values for the rope segments. If the parameters exceed these values, the maximum values are set instead of the requested values.
---@param max1 number @The new maximum length of the first segment.
---@param max2 number @The new maximum length of the second segment.
function LovePulleyJoint:setMaxLengths(max1, max2)
end

---Set the pulley ratio.
---@param ratio number @The new pulley ratio of the joint.
function LovePulleyJoint:setRatio(ratio)
end

-- endregion LovePulleyJoint
-- region LoveRevoluteJoint
---@class LoveRevoluteJoint
---Allow two Bodies to revolve around a shared point.
local LoveRevoluteJoint = {}
---Checks whether limits are enabled.
---@return boolean
function LoveRevoluteJoint:areLimitsEnabled()
end

---Get the current joint angle.
---@return number
function LoveRevoluteJoint:getJointAngle()
end

---Get the current joint angle speed.
---@return number
function LoveRevoluteJoint:getJointSpeed()
end

---Gets the joint limits.
---@return number, number
function LoveRevoluteJoint:getLimits()
end

---Gets the lower limit.
---@return number
function LoveRevoluteJoint:getLowerLimit()
end

---Gets the maximum motor force.
---@return number
function LoveRevoluteJoint:getMaxMotorTorque()
end

---Gets the motor speed.
---@return number
function LoveRevoluteJoint:getMotorSpeed()
end

---Get the current motor force.
---@return number
function LoveRevoluteJoint:getMotorTorque()
end

---Gets the upper limit.
---@return number
function LoveRevoluteJoint:getUpperLimit()
end

---Checks whether limits are enabled.
---@return boolean
function LoveRevoluteJoint:hasLimitsEnabled()
end

---Checks whether the motor is enabled.
---@return boolean
function LoveRevoluteJoint:isMotorEnabled()
end

---Sets the limits.
---@param lower number @The lower limit, in radians.
---@param upper number @The upper limit, in radians.
function LoveRevoluteJoint:setLimits(lower, upper)
end

---Enables/disables the joint limit.
---@param enable boolean @True to enable, false to disable.
function LoveRevoluteJoint:setLimitsEnabled(enable)
end

---Sets the lower limit.
---@param lower number @The lower limit, in radians.
function LoveRevoluteJoint:setLowerLimit(lower)
end

---Set the maximum motor force.
---@param f number @The maximum motor force, in Nm.
function LoveRevoluteJoint:setMaxMotorTorque(f)
end

---Enables/disables the joint motor.
---@param enable boolean @True to enable, false to disable.
function LoveRevoluteJoint:setMotorEnabled(enable)
end

---Sets the motor speed.
---@param s number @The motor speed, radians per second.
function LoveRevoluteJoint:setMotorSpeed(s)
end

---Sets the upper limit.
---@param upper number @The upper limit, in radians.
function LoveRevoluteJoint:setUpperLimit(upper)
end

-- endregion LoveRevoluteJoint
-- region LoveRopeJoint
---@class LoveRopeJoint
---The LoveRopeJoint enforces a maximum distance between two points on two bodies. It has no other effect.
local LoveRopeJoint = {}
---Gets the maximum length of a LoveRopeJoint.
---@return number
function LoveRopeJoint:getMaxLength()
end

---Sets the maximum length of a LoveRopeJoint.
---@param maxLength number @The new maximum length of the LoveRopeJoint.
function LoveRopeJoint:setMaxLength(maxLength)
end

-- endregion LoveRopeJoint
-- region LoveShape
---@class LoveShape
---Shapes are solid 2d geometrical objects which handle the mass and collision of a LoveBody in love.physics.
---
---Shapes are attached to a LoveBody via a LoveFixture. The LoveShape object is copied when this happens. 
---
---The LoveShape's position is relative to the position of the LoveBody it has been attached to.
local LoveShape = {}
---Returns the points of the bounding box for the transformed shape.
---@param tx number @The translation of the shape on the x-axis.
---@param ty number @The translation of the shape on the y-axis.
---@param tr number @The shape rotation.
---@param childIndex number @The index of the child to compute the bounding box of.
---@return number, number, number, number
function LoveShape:computeAABB(tx, ty, tr, childIndex)
end

---Computes the mass properties for the shape with the specified density.
---@param density number @The shape density.
---@return number, number, number, number
function LoveShape:computeMass(density)
end

---Returns the number of children the shape has.
---@return number
function LoveShape:getChildCount()
end

---Gets the radius of the shape.
---@return number
function LoveShape:getRadius()
end

---Gets a string representing the LoveShape.
---
---This function can be useful for conditional debug drawing.
---@return ShapeType
function LoveShape:getType()
end

---Casts a ray against the shape and returns the surface normal vector and the line position where the ray hit. If the ray missed the shape, nil will be returned. The LoveShape can be transformed to get it into the desired position.
---
---The ray starts on the first point of the input line and goes towards the second point of the line. The fourth argument is the maximum distance the ray is going to travel as a scale factor of the input line length.
---
---The childIndex parameter is used to specify which child of a parent shape, such as a LoveChainShape, will be ray casted. For ChainShapes, the index of 1 is the first edge on the chain. Ray casting a parent shape will only test the child specified so if you want to test every shape of the parent, you must loop through all of its children.
---
---The world position of the impact can be calculated by multiplying the line vector with the third return value and adding it to the line starting point.
---
---hitx, hity = x1 + (x2 - x1) * fraction, y1 + (y2 - y1) * fraction
---@param x1 number @The x position of the input line starting point.
---@param y1 number @The y position of the input line starting point.
---@param x2 number @The x position of the input line end point.
---@param y2 number @The y position of the input line end point.
---@param maxFraction number @Ray length parameter.
---@param tx number @The translation of the shape on the x-axis.
---@param ty number @The translation of the shape on the y-axis.
---@param tr number @The shape rotation.
---@param childIndex number @The index of the child the ray gets cast against.
---@return number, number, number
function LoveShape:rayCast(x1, y1, x2, y2, maxFraction, tx, ty, tr, childIndex)
end

---This is particularly useful for mouse interaction with the shapes. By looping through all shapes and testing the mouse position with this function, we can find which shapes the mouse touches.
---@param tx number @Translates the shape along the x-axis.
---@param ty number @Translates the shape along the y-axis.
---@param tr number @Rotates the shape.
---@param x number @The x-component of the point.
---@param y number @The y-component of the point.
---@return boolean
function LoveShape:testPoint(tx, ty, tr, x, y)
end

-- endregion LoveShape
-- region LoveWeldJoint
---@class LoveWeldJoint
---A LoveWeldJoint essentially glues two bodies together.
local LoveWeldJoint = {}
---Returns the damping ratio of the joint.
---@return number
function LoveWeldJoint:getDampingRatio()
end

---Returns the frequency.
---@return number
function LoveWeldJoint:getFrequency()
end

---Sets a new damping ratio.
---@param ratio number @The new damping ratio.
function LoveWeldJoint:setDampingRatio(ratio)
end

---Sets a new frequency.
---@param freq number @The new frequency in hertz.
function LoveWeldJoint:setFrequency(freq)
end

-- endregion LoveWeldJoint
-- region LoveWheelJoint
---@class LoveWheelJoint
---Restricts a point on the second body to a line on the first body.
local LoveWheelJoint = {}
---Gets the world-space axis vector of the Wheel LoveJoint.
---@return number, number
function LoveWheelJoint:getAxis()
end

---Returns the current joint translation speed.
---@return number
function LoveWheelJoint:getJointSpeed()
end

---Returns the current joint translation.
---@return number
function LoveWheelJoint:getJointTranslation()
end

---Returns the maximum motor torque.
---@return number
function LoveWheelJoint:getMaxMotorTorque()
end

---Returns the speed of the motor.
---@return number
function LoveWheelJoint:getMotorSpeed()
end

---Returns the current torque on the motor.
---@param invdt number @How long the force applies. Usually the inverse time step or 1/dt.
---@return number
function LoveWheelJoint:getMotorTorque(invdt)
end

---Returns the damping ratio.
---@return number
function LoveWheelJoint:getSpringDampingRatio()
end

---Returns the spring frequency.
---@return number
function LoveWheelJoint:getSpringFrequency()
end

---Sets a new maximum motor torque.
---@param maxTorque number @The new maximum torque for the joint motor in newton meters.
function LoveWheelJoint:setMaxMotorTorque(maxTorque)
end

---Starts and stops the joint motor.
---@param enable boolean @True turns the motor on and false turns it off.
function LoveWheelJoint:setMotorEnabled(enable)
end

---Sets a new speed for the motor.
---@param speed number @The new speed for the joint motor in radians per second.
function LoveWheelJoint:setMotorSpeed(speed)
end

---Sets a new damping ratio.
---@param ratio number @The new damping ratio.
function LoveWheelJoint:setSpringDampingRatio(ratio)
end

---Sets a new spring frequency.
---@param freq number @The new frequency in hertz.
function LoveWheelJoint:setSpringFrequency(freq)
end

-- endregion LoveWheelJoint
-- region World
---@class World
---A world is an object that contains all bodies and joints.
local World = {}
---Destroys the world, taking all bodies, joints, fixtures and their shapes with it. 
---
---An error will occur if you attempt to use any of the destroyed objects after calling this function.
function World:destroy()
end

---Returns a table with all bodies.
---@return table
function World:getBodies()
end

---Returns the number of bodies in the world.
---@return number
function World:getBodyCount()
end

---Returns functions for the callbacks during the world update.
---@return function, function, function, function
function World:getCallbacks()
end

---Returns the number of contacts in the world.
---@return number
function World:getContactCount()
end

---Returns the function for collision filtering.
---@return function
function World:getContactFilter()
end

---Returns a table with all Contacts.
---@return table
function World:getContacts()
end

---Get the gravity of the world.
---@return number, number
function World:getGravity()
end

---Returns the number of joints in the world.
---@return number
function World:getJointCount()
end

---Returns a table with all joints.
---@return table
function World:getJoints()
end

---Gets whether the World is destroyed. Destroyed worlds cannot be used.
---@return boolean
function World:isDestroyed()
end

---Returns if the world is updating its state.
---
---This will return true inside the callbacks from World:setCallbacks.
---@return boolean
function World:isLocked()
end

---Gets the sleep behaviour of the world.
---@return boolean
function World:isSleepingAllowed()
end

---Calls a function for each fixture inside the specified area by searching for any overlapping bounding box (LoveFixture:getBoundingBox).
---@param topLeftX number @The x position of the top-left point.
---@param topLeftY number @The y position of the top-left point.
---@param bottomRightX number @The x position of the bottom-right point.
---@param bottomRightY number @The y position of the bottom-right point.
---@param callback function @This function gets passed one argument, the fixture, and should return a boolean. The search will continue if it is true or stop if it is false.
function World:queryBoundingBox(topLeftX, topLeftY, bottomRightX, bottomRightY, callback)
end

---Casts a ray and calls a function for each fixtures it intersects. 
---@param fixture LoveFixture @The fixture intersecting the ray.
---@param x number @The x position of the intersection point.
---@param y number @The y position of the intersection point.
---@param xn number @The x value of the surface normal vector of the shape edge.
---@param yn number @The y value of the surface normal vector of the shape edge.
---@param fraction number @The position of the intersection on the ray as a number from 0 to 1 (or even higher if the ray length was changed with the return value).
---@return number
function World:rayCast(fixture, x, y, xn, yn, fraction)
end

---Sets functions for the collision callbacks during the world update.
---
---Four Lua functions can be given as arguments. The value nil removes a function.
---
---When called, each function will be passed three arguments. The first two arguments are the colliding fixtures and the third argument is the LoveContact between them. The postSolve callback additionally gets the normal and tangent impulse for each contact point. See notes.
---
---If you are interested to know when exactly each callback is called, consult a Box2d manual
---@param beginContact function @Gets called when two fixtures begin to overlap.
---@param endContact function @Gets called when two fixtures cease to overlap. This will also be called outside of a world update, when colliding objects are destroyed.
---@param preSolve function @Gets called before a collision gets resolved.
---@param postSolve function @Gets called after the collision has been resolved.
function World:setCallbacks(beginContact, endContact, preSolve, postSolve)
end

---Sets a function for collision filtering.
---
---If the group and category filtering doesn't generate a collision decision, this function gets called with the two fixtures as arguments. The function should return a boolean value where true means the fixtures will collide and false means they will pass through each other.
---@param filter function @The function handling the contact filtering.
function World:setContactFilter(filter)
end

---Set the gravity of the world.
---@param x number @The x component of gravity.
---@param y number @The y component of gravity.
function World:setGravity(x, y)
end

---Sets the sleep behaviour of the world.
---@param allow boolean @True if bodies in the world are allowed to sleep, or false if not.
function World:setSleepingAllowed(allow)
end

---Translates the World's origin. Useful in large worlds where floating point precision issues become noticeable at far distances from the origin.
---@param x number @The x component of the new origin with respect to the old origin.
---@param y number @The y component of the new origin with respect to the old origin.
function World:translateOrigin(x, y)
end

---Update the state of the world.
---@param dt number @The time (in seconds) to advance the physics simulation.
---@param velocityiterations number @The maximum number of steps used to determine the new velocities when resolving a collision.
---@param positioniterations number @The maximum number of steps used to determine the new positions when resolving a collision.
function World:update(dt, velocityiterations, positioniterations)
end

-- endregion World
---The types of a LoveBody. 
BodyType = {
    ---Static bodies do not move.
    ["static"] = 1,
    ---Dynamic bodies collide with all bodies.
    ["dynamic"] = 2,
    ---Kinematic bodies only collide with dynamic bodies.
    ["kinematic"] = 3
}
---Different types of joints.
JointType = {
    ---A LoveDistanceJoint.
    ["distance"] = 1,
    ---A LoveFrictionJoint.
    ["friction"] = 2,
    ---A LoveGearJoint.
    ["gear"] = 3,
    ---A LoveMouseJoint.
    ["mouse"] = 4,
    ---A LovePrismaticJoint.
    ["prismatic"] = 5,
    ---A LovePulleyJoint.
    ["pulley"] = 6,
    ---A LoveRevoluteJoint.
    ["revolute"] = 7,
    ---A LoveRopeJoint.
    ["rope"] = 8,
    ---A LoveWeldJoint.
    ["weld"] = 9
}
---The different types of Shapes, as returned by LoveShape:getType.
ShapeType = {
    ---The LoveShape is a LoveCircleShape.
    ["circle"] = 1,
    ---The LoveShape is a LovePolygonShape.
    ["polygon"] = 2,
    ---The LoveShape is a LoveEdgeShape.
    ["edge"] = 3,
    ---The LoveShape is a LoveChainShape.
    ["chain"] = 4
}
---Returns the two closest points between two fixtures and their distance.
---@param fixture1 LoveFixture @The first fixture.
---@param fixture2 LoveFixture @The second fixture.
---@return number, number, number, number, number
function m.getDistance(fixture1, fixture2)
end

---Returns the meter scale factor.
---
---All coordinates in the physics module are divided by this number, creating a convenient way to draw the objects directly to the screen without the need for graphics transformations.
---
---It is recommended to create shapes no larger than 10 times the scale. This is important because Box2D is tuned to work well with shape sizes from 0.1 to 10 meters.
---@return number
function m.getMeter()
end

---Creates a new body.
---
---There are three types of bodies. 
---
---* Static bodies do not move, have a infinite mass, and can be used for level boundaries. 
---
---* Dynamic bodies are the main actors in the simulation, they collide with everything. 
---
---* Kinematic bodies do not react to forces and only collide with dynamic bodies.
---
---The mass of the body gets calculated when a LoveFixture is attached or removed, but can be changed at any time with LoveBody:setMass or LoveBody:resetMassData.
---@param world World @The world to create the body in.
---@param x number @The x position of the body.
---@param y number @The y position of the body.
---@param type BodyType @The type of the body.
---@return LoveBody
function m.newBody(world, x, y, type)
end

---Creates a new LoveChainShape.
---@param loop boolean @If the chain should loop back to the first point.
---@param x1 number @The x position of the first point.
---@param y1 number @The y position of the first point.
---@param x2 number @The x position of the second point.
---@param y2 number @The y position of the second point.
---@param ... number @Additional point positions.
---@return LoveChainShape
---@overload fun(loop:boolean, points:table):LoveChainShape
function m.newChainShape(loop, x1, y1, x2, y2, ...)
end

---Creates a new LoveCircleShape.
---@param radius number @The radius of the circle.
---@return LoveCircleShape
---@overload fun(x:number, y:number, radius:number):LoveCircleShape
function m.newCircleShape(radius)
end

---Creates a LoveDistanceJoint between two bodies.
---
---This joint constrains the distance between two points on two bodies to be constant. These two points are specified in world coordinates and the two bodies are assumed to be in place when this joint is created. The first anchor point is connected to the first body and the second to the second body, and the points define the length of the distance joint.
---@param body1 LoveBody @The first body to attach to the joint.
---@param body2 LoveBody @The second body to attach to the joint.
---@param x1 number @The x position of the first anchor point (world space).
---@param y1 number @The y position of the first anchor point (world space).
---@param x2 number @The x position of the second anchor point (world space).
---@param y2 number @The y position of the second anchor point (world space).
---@param collideConnected boolean @Specifies whether the two bodies should collide with each other.
---@return LoveDistanceJoint
function m.newDistanceJoint(body1, body2, x1, y1, x2, y2, collideConnected)
end

---Creates a new LoveEdgeShape.
---@param x1 number @The x position of the first point.
---@param y1 number @The y position of the first point.
---@param x2 number @The x position of the second point.
---@param y2 number @The y position of the second point.
---@return LoveEdgeShape
function m.newEdgeShape(x1, y1, x2, y2)
end

---Creates and attaches a LoveFixture to a body.
---
---Note that the LoveShape object is copied rather than kept as a reference when the LoveFixture is created. To get the LoveShape object that the LoveFixture owns, use LoveFixture:getShape.
---@param body LoveBody @The body which gets the fixture attached.
---@param shape LoveShape @The shape to be copied to the fixture.
---@param density number @The density of the fixture.
---@return LoveFixture
function m.newFixture(body, shape, density)
end

---Create a friction joint between two bodies. A LoveFrictionJoint applies friction to a body.
---@param body1 LoveBody @The first body to attach to the joint.
---@param body2 LoveBody @The second body to attach to the joint.
---@param x number @The x position of the anchor point.
---@param y number @The y position of the anchor point.
---@param collideConnected boolean @Specifies whether the two bodies should collide with each other.
---@return LoveFrictionJoint
---@overload fun(body1:LoveBody, body2:LoveBody, x1:number, y1:number, x2:number, y2:number, collideConnected:boolean):LoveFrictionJoint
function m.newFrictionJoint(body1, body2, x, y, collideConnected)
end

---Create a LoveGearJoint connecting two Joints.
---
---The gear joint connects two joints that must be either  prismatic or  revolute joints. Using this joint requires that the joints it uses connect their respective bodies to the ground and have the ground as the first body. When destroying the bodies and joints you must make sure you destroy the gear joint before the other joints.
---
---The gear joint has a ratio the determines how the angular or distance values of the connected joints relate to each other. The formula coordinate1 + ratio * coordinate2 always has a constant value that is set when the gear joint is created.
---@param joint1 LoveJoint @The first joint to connect with a gear joint.
---@param joint2 LoveJoint @The second joint to connect with a gear joint.
---@param ratio number @The gear ratio.
---@param collideConnected boolean @Specifies whether the two bodies should collide with each other.
---@return LoveGearJoint
function m.newGearJoint(joint1, joint2, ratio, collideConnected)
end

---Creates a joint between two bodies which controls the relative motion between them.
---
---Position and rotation offsets can be specified once the LoveMotorJoint has been created, as well as the maximum motor force and torque that will be be applied to reach the target offsets.
---@param body1 LoveBody @The first body to attach to the joint.
---@param body2 LoveBody @The second body to attach to the joint.
---@param correctionFactor number @The joint's initial position correction factor, in the range of 1.
---@return LoveMotorJoint
---@overload fun(body1:LoveBody, body2:LoveBody, correctionFactor:number, collideConnected:boolean):LoveMotorJoint
function m.newMotorJoint(body1, body2, correctionFactor)
end

---Create a joint between a body and the mouse.
---
---This joint actually connects the body to a fixed point in the world. To make it follow the mouse, the fixed point must be updated every timestep (example below).
---
---The advantage of using a LoveMouseJoint instead of just changing a body position directly is that collisions and reactions to other joints are handled by the physics engine. 
---@param body LoveBody @The body to attach to the mouse.
---@param x number @The x position of the connecting point.
---@param y number @The y position of the connecting point.
---@return LoveMouseJoint
function m.newMouseJoint(body, x, y)
end

---Creates a new LovePolygonShape.
---
---This shape can have 8 vertices at most, and must form a convex shape.
---@param x1 number @The x position of the first point.
---@param y1 number @The y position of the first point.
---@param x2 number @The x position of the second point.
---@param y2 number @The y position of the second point.
---@param x3 number @The x position of the third point.
---@param y3 number @The y position of the third point.
---@param ... number @You can continue passing more point positions to create the LovePolygonShape.
---@return LovePolygonShape
---@overload fun(vertices:table):LovePolygonShape
function m.newPolygonShape(x1, y1, x2, y2, x3, y3, ...)
end

---Creates a LovePrismaticJoint between two bodies.
---
---A prismatic joint constrains two bodies to move relatively to each other on a specified axis. It does not allow for relative rotation. Its definition and operation are similar to a  revolute joint, but with translation and force substituted for angle and torque.
---@param body1 LoveBody @The first body to connect with a prismatic joint.
---@param body2 LoveBody @The second body to connect with a prismatic joint.
---@param x number @The x coordinate of the anchor point.
---@param y number @The y coordinate of the anchor point.
---@param ax number @The x coordinate of the axis vector.
---@param ay number @The y coordinate of the axis vector.
---@param collideConnected boolean @Specifies whether the two bodies should collide with each other.
---@return LovePrismaticJoint
---@overload fun(body1:LoveBody, body2:LoveBody, x1:number, y1:number, x2:number, y2:number, ax:number, ay:number, collideConnected:boolean):LovePrismaticJoint
---@overload fun(body1:LoveBody, body2:LoveBody, x1:number, y1:number, x2:number, y2:number, ax:number, ay:number, collideConnected:boolean, referenceAngle:number):LovePrismaticJoint
function m.newPrismaticJoint(body1, body2, x, y, ax, ay, collideConnected)
end

---Creates a LovePulleyJoint to join two bodies to each other and the ground.
---
---The pulley joint simulates a pulley with an optional block and tackle. If the ratio parameter has a value different from one, then the simulated rope extends faster on one side than the other. In a pulley joint the total length of the simulated rope is the constant length1 + ratio * length2, which is set when the pulley joint is created.
---
---Pulley joints can behave unpredictably if one side is fully extended. It is recommended that the method  setMaxLengths  be used to constrain the maximum lengths each side can attain.
---@param body1 LoveBody @The first body to connect with a pulley joint.
---@param body2 LoveBody @The second body to connect with a pulley joint.
---@param gx1 number @The x coordinate of the first body's ground anchor.
---@param gy1 number @The y coordinate of the first body's ground anchor.
---@param gx2 number @The x coordinate of the second body's ground anchor.
---@param gy2 number @The y coordinate of the second body's ground anchor.
---@param x1 number @The x coordinate of the pulley joint anchor in the first body.
---@param y1 number @The y coordinate of the pulley joint anchor in the first body.
---@param x2 number @The x coordinate of the pulley joint anchor in the second body.
---@param y2 number @The y coordinate of the pulley joint anchor in the second body.
---@param ratio number @The joint ratio.
---@param collideConnected boolean @Specifies whether the two bodies should collide with each other.
---@return LovePulleyJoint
function m.newPulleyJoint(body1, body2, gx1, gy1, gx2, gy2, x1, y1, x2, y2, ratio, collideConnected)
end

---Shorthand for creating rectangular PolygonShapes. 
---
---By default, the local origin is located at the '''center''' of the rectangle as opposed to the top left for graphics.
---@param width number @The width of the rectangle.
---@param height number @The height of the rectangle.
---@return LovePolygonShape
---@overload fun(x:number, y:number, width:number, height:number, angle:number):LovePolygonShape
function m.newRectangleShape(width, height)
end

---Creates a pivot joint between two bodies.
---
---This joint connects two bodies to a point around which they can pivot.
---@param body1 LoveBody @The first body.
---@param body2 LoveBody @The second body.
---@param x number @The x position of the connecting point.
---@param y number @The y position of the connecting point.
---@param collideConnected boolean @Specifies whether the two bodies should collide with each other.
---@return LoveRevoluteJoint
---@overload fun(body1:LoveBody, body2:LoveBody, x1:number, y1:number, x2:number, y2:number, collideConnected:boolean, referenceAngle:number):LoveRevoluteJoint
function m.newRevoluteJoint(body1, body2, x, y, collideConnected)
end

---Creates a joint between two bodies. Its only function is enforcing a max distance between these bodies.
---@param body1 LoveBody @The first body to attach to the joint.
---@param body2 LoveBody @The second body to attach to the joint.
---@param x1 number @The x position of the first anchor point.
---@param y1 number @The y position of the first anchor point.
---@param x2 number @The x position of the second anchor point.
---@param y2 number @The y position of the second anchor point.
---@param maxLength number @The maximum distance for the bodies.
---@param collideConnected boolean @Specifies whether the two bodies should collide with each other.
---@return LoveRopeJoint
function m.newRopeJoint(body1, body2, x1, y1, x2, y2, maxLength, collideConnected)
end

---Creates a constraint joint between two bodies. A LoveWeldJoint essentially glues two bodies together. The constraint is a bit soft, however, due to Box2D's iterative solver.
---@param body1 LoveBody @The first body to attach to the joint.
---@param body2 LoveBody @The second body to attach to the joint.
---@param x number @The x position of the anchor point (world space).
---@param y number @The y position of the anchor point (world space).
---@param collideConnected boolean @Specifies whether the two bodies should collide with each other.
---@return LoveWeldJoint
---@overload fun(body1:LoveBody, body2:LoveBody, x1:number, y1:number, x2:number, y2:number, collideConnected:boolean):LoveWeldJoint
---@overload fun(body1:LoveBody, body2:LoveBody, x1:number, y1:number, x2:number, y2:number, collideConnected:boolean, referenceAngle:number):LoveWeldJoint
function m.newWeldJoint(body1, body2, x, y, collideConnected)
end

---Creates a wheel joint.
---@param body1 LoveBody @The first body.
---@param body2 LoveBody @The second body.
---@param x number @The x position of the anchor point.
---@param y number @The y position of the anchor point.
---@param ax number @The x position of the axis unit vector.
---@param ay number @The y position of the axis unit vector.
---@param collideConnected boolean @Specifies whether the two bodies should collide with each other.
---@return LoveWheelJoint
---@overload fun(body1:LoveBody, body2:LoveBody, x1:number, y1:number, x2:number, y2:number, ax:number, ay:number, collideConnected:boolean):LoveWheelJoint
function m.newWheelJoint(body1, body2, x, y, ax, ay, collideConnected)
end

---Creates a new World.
---@param xg number @The x component of gravity.
---@param yg number @The y component of gravity.
---@param sleep boolean @Whether the bodies in this world are allowed to sleep.
---@return World
function m.newWorld(xg, yg, sleep)
end

---Sets the pixels to meter scale factor.
---
---All coordinates in the physics module are divided by this number and converted to meters, and it creates a convenient way to draw the objects directly to the screen without the need for graphics transformations.
---
---It is recommended to create shapes no larger than 10 times the scale. This is important because Box2D is tuned to work well with shape sizes from 0.1 to 10 meters. The default meter scale is 30.
---@param scale number @The scale factor as an integer.
function m.setMeter(scale)
end

return m
