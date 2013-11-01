//
//  GameScene.m
//  SKInvaders
//

//  Copyright (c) 2013 RepublicOfApps, LLC. All rights reserved.
//

#import "GameScene.h"
#import "GameOverScene.h"
#import <CoreMotion/CoreMotion.h>

#pragma mark - Custom Type Definitions
//! Define the possible types of invader enemies. You can use this in switch statements later when you need to do things such as displaying different sprite images for each enemy type. The typedef also makes InvaderType a formal Objective-C type that is type-checked for method arguments and variables. This ensures that you don’t pass the wrong method argument or assign it to the wrong variable.
typedef enum InvaderType {
    InvaderTypeA,
    InvaderTypeB,
    InvaderTypeC
} InvaderType;
//! Invaders move in a fixed pattern: right, right, down, left, left, down, right, right, ... so you'll use the InvaderMovementDirection type to track the invaders' progress through this pattern. For example, InvaderMovementDirectionRight means the invaders are in the right, right portion of their pattern
typedef enum InvaderMovementDirection {
    InvaderMovementDirectionRight,
    InvaderMovementDirectionLeft,
    InvaderMovementDirectionDownThenRight,
    InvaderMovementDirectionDownThenLeft,
    InvaderMovementDirectionNone
} InvaderMovementDirection;

//! Use BulletType to define the bullet code for both invaders and your ship.
typedef enum BulletType {
    ShipFiredBulletType,
    InvaderFiredBulletType
} BulletType;

//! Define the size of the invaders and that they’ll be laid out in a grid of rows and columns on the screen.
#define kInvaderSize CGSizeMake(24, 16)
#define kInvaderGridSpacing CGSizeMake(12, 12)
#define kInvaderRowCount 6
#define kInvaderColCount 6
//! Define a name you’ll use to identify invaders when searching for them in the scene
#define kInvaderName @"invader"
//! Define a name and size for the ship
#define kShipSize CGSizeMake(30, 16)
#define kShipName @"ship"
//! Define the heads up display for keeping score
#define kScoreHudName @"scoreHud"
#define kHealthHudName @"healthHud"
#define kMinInvaderBottomHeight 2 * kShipSize.height

static const u_int32_t kInvaderCategory            = 0x1 << 0;
static const u_int32_t kShipFiredBulletCategory    = 0x1 << 1;
static const u_int32_t kShipCategory               = 0x1 << 2;
static const u_int32_t kSceneEdgeCategory          = 0x1 << 3;
static const u_int32_t kInvaderFiredBulletCategory = 0x1 << 4;

#pragma mark - Private GameScene Properties
//! Define the bullet information for the HUD (size and label)
#define kShipFiredBulletName @"shipFiredBullet"
#define kInvaderFiredBulletName @"invaderFiredBullet"
#define kBulletSize CGSizeMake(4, 8)

@interface GameScene ()
@property BOOL contentCreated;
@property InvaderMovementDirection invaderMovementDirection;
@property NSTimeInterval timeOfLastMove;
@property NSTimeInterval timePerMove;
@property (strong) CMMotionManager* motionManager;
//! Queues
@property (strong) NSMutableArray* tapQueue;
@property (strong) NSMutableArray* contactQueue;
//! HUD Values
@property NSUInteger score;
@property CGFloat shipHealth;
@property BOOL gameEnding;
@end


@implementation GameScene

#pragma mark Object Lifecycle Management

#pragma mark - Scene Setup and Content Creation

//! This method invokes createContent using the BOOL property contentCreated to make sure you don’t create your scene’s content more than once.
- (void)didMoveToView:(SKView *)view
{
    if (!self.contentCreated) {
        [self createContent];
        self.contentCreated = YES;
        self.motionManager = [[CMMotionManager alloc] init];
        [self.motionManager startAccelerometerUpdates];
        self.tapQueue = [NSMutableArray array];
        self.userInteractionEnabled = YES;
        self.contactQueue = [NSMutableArray array];
        self.physicsWorld.contactDelegate = self;
    }
}

//! Create a scene’s content by referencing sprite nodes, their starting position and adding them to the scene
- (void)createContent
{
    //1 Invaders begin by moving to the right.
    self.invaderMovementDirection = InvaderMovementDirectionRight;
    //2 Invaders take 1 second for each move. Each step left, right or down takes 1 second.
    self.timePerMove = 1.0;
    //3 Invaders haven't moved yet, so set the time to zero.
    self.timeOfLastMove = 0.0;
    
    // Creates an edge loop for the scene
    self.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];
    
    // Sets the category for the physics body of the game scene.
    self.physicsBody.categoryBitMask = kSceneEdgeCategory;
    
    [self setupInvaders];
    [self setupShip];
    [self setupHud];
    
    
    //  Sample Code for showing a single invader
    //    SKSpriteNode* invader = [SKSpriteNode spriteNodeWithImageNamed:@"InvaderA_00.png"];
    //    invader.position = CGPointMake(self.size.width/2, self.size.height/2);
    //    [self addChild:invader];
}


-(NSArray*)loadInvaderTexturesOfType:(InvaderType)invaderType {
    NSString* prefix;
    switch (invaderType) {
        case InvaderTypeA:
            prefix = @"InvaderA";
            
            break;
        case InvaderTypeB:
            prefix = @"InvaderB";
            break;
        case InvaderTypeC:
        default:
            prefix = @"InvaderC";
            break;
    }
    //1 Loads a pair of sprite images — InvaderA_00.png and InvaderA_01.png — for each invader type and creates SKTexture objects from them.
    return @[[SKTexture textureWithImageNamed:[NSString stringWithFormat:@"%@_00.png", prefix]],
             [SKTexture textureWithImageNamed:[NSString stringWithFormat:@"%@_01.png", prefix]]];
}

-(SKNode*)makeInvaderOfType:(InvaderType)invaderType {
    NSArray* invaderTextures = [self loadInvaderTexturesOfType:invaderType];
    //2 Uses the first such texture as the sprite's base image.
    SKSpriteNode* invader = [SKSpriteNode spriteNodeWithTexture:[invaderTextures firstObject]];
   
    
    //change color based on invader type
    SKColor* invaderColor;
    switch (invaderType) {
        case InvaderTypeA:
            invaderColor = [SKColor redColor];
            break;
        case InvaderTypeB:
            invaderColor = [SKColor greenColor];
            break;
        case InvaderTypeC:
        default:
            invaderColor = [SKColor blueColor];
            break;
    }
    
    invader.color = invaderColor;
    invader.name = kInvaderName;
    
    //3 Animates these two images in a continuous animation loop
    [invader runAction:[SKAction repeatActionForever:[SKAction animateWithTextures:invaderTextures timePerFrame:self.timePerMove]]];
    
    invader.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:invader.frame.size];
    invader.physicsBody.dynamic = NO;
    invader.physicsBody.categoryBitMask = kInvaderCategory;
    invader.physicsBody.contactTestBitMask = 0x0;
    invader.physicsBody.collisionBitMask = 0x0;
    
    return invader;
}
/*! Creates an invader sprite of a given type.
 
 @param invaderType (SKColor*): Determines the color of the invader.
 @param kInvaderSize (CGSize): Determines size of invader rectangle.
 @note Call the handy convenience method spriteNodeWithColor:size: of SKSpriteNode to allocate and initialize a sprite that renders as a rectangle of the given color invaderColor with size kInvaderSize
 @return - Invader SKNode
 
 */
//-(SKNode*)makeInvaderOfType:(InvaderType)invaderType {
//    //1
//    SKColor* invaderColor;
//    switch (invaderType) {
//        case InvaderTypeA:
//            invaderColor = [SKColor redColor];
//            break;
//        case InvaderTypeB:
//            invaderColor = [SKColor greenColor];
//            break;
//        case InvaderTypeC:
//        default:
//            invaderColor = [SKColor blueColor];
//            break;
//    }
//    
//    //2
//    SKSpriteNode* invader = [SKSpriteNode spriteNodeWithColor:invaderColor size:kInvaderSize];
//    invader.name = kInvaderName;
//    
//    //This code gives your invader a physics body and identifies it as an invader using kInvaderCategory. It also indicates that you don't want invaders to contact or collide with other entities.
//    invader.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:invader.frame.size];
//    invader.physicsBody.dynamic = NO;
//    invader.physicsBody.categoryBitMask = kInvaderCategory;
//    invader.physicsBody.contactTestBitMask = 0x0;
//    invader.physicsBody.collisionBitMask = 0x0;
//    return invader;
//}

//! Configure a grid of invaders
-(void)setupInvaders {
    //1  Loop over the rows
    CGPoint baseOrigin = CGPointMake(kInvaderSize.width / 2, 180);
    for (NSUInteger row = 0; row < kInvaderRowCount; ++row) {
        //2 Choose a single InvaderType for all invaders in this row based on the row number
        InvaderType invaderType;
        if (row % 3 == 0)      invaderType = InvaderTypeA;
        else if (row % 3 == 1) invaderType = InvaderTypeB;
        else                   invaderType = InvaderTypeC;
        
        //3  Do some math to figure out where the first invader in this row should be positioned
        CGPoint invaderPosition = CGPointMake(baseOrigin.x, row * (kInvaderGridSpacing.height + kInvaderSize.height) + baseOrigin.y);
        
        //4 Loop over the columns
        for (NSUInteger col = 0; col < kInvaderColCount; ++col) {
            //5  Create an invader for the current row and column and add it to the scene
            SKNode* invader = [self makeInvaderOfType:invaderType];
            invader.position = invaderPosition;
            [self addChild:invader];
            //6 Update the invaderPosition so that it's correct for the next invader
            invaderPosition.x += kInvaderSize.width + kInvaderGridSpacing.width;
        }
    }
}
-(void)setupShip {
    //1 Create a ship using makeShip. You can easily reuse makeShip later if you need to create another ship (e.g. if the current ship gets destroyed by an invader and the player has "lives" left).
    SKNode* ship = [self makeShip];
    //2 Place the ship on the screen. In Sprite Kit, the origin is at the lower left corner of the screen. The anchorPoint is based on a unit square with (0, 0) at the lower left of the sprite's area and (1, 1) at its top right. Since SKSpriteNode has a default anchorPoint of (0.5, 0.5), i.e., its center, the ship's position is the position of its center. Positioning the ship at kShipSize.height/2.0f means that half of the ship's height will protrude below its position and half above. If you check the math, you'll see that the ship's bottom aligns exactly with the bottom of the scene.
    ship.position = CGPointMake(self.size.width / 2.0f, kShipSize.height/2.0f);
    [self addChild:ship];
    self.shipHealth = 1.0f;
}
-(SKNode*)makeShip {
    //1 Your ship sprite is now constructed from an image.
    SKSpriteNode* ship = [SKSpriteNode spriteNodeWithImageNamed:@"Ship.png"];
    ship.name = kShipName;
    
    //2 Originally, the ship image is white, just like the invader images. But the code sets the sprite color to make the image green. Effectively this blends the green color with the sprite image.
    ship.color = [UIColor greenColor];
    ship.colorBlendFactor = 1.0f;
    ship.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:ship.frame.size];
    ship.physicsBody.dynamic = YES;
    ship.physicsBody.affectedByGravity = NO;
    ship.physicsBody.mass = 0.02;
    ship.physicsBody.categoryBitMask = kShipCategory;
    ship.physicsBody.contactTestBitMask = 0x0;
    ship.physicsBody.collisionBitMask = kSceneEdgeCategory;
    
    return ship;
}
//-(SKNode*)makeShip {
//    SKNode* ship = [SKSpriteNode spriteNodeWithColor:[SKColor greenColor] size:kShipSize];
//    ship.name = kShipName;
//    //1 Create a rectangular physics body the same size as the ship
//    ship.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:ship.frame.size];
//    //2 Make the shape dynamic; this makes it subject to things such as collisions and other outside forces
//    ship.physicsBody.dynamic = YES;
//    //3 You don't want the ship to drop off the bottom of the screen, so you indicate that it's not affected by gravity
//    ship.physicsBody.affectedByGravity = NO;
//    //4 Give the ship an arbitrary mass so that its movement feels natural
//    ship.physicsBody.mass = 0.02;
//    //1 Set the ship's category
//    ship.physicsBody.categoryBitMask = kShipCategory;
//    //2 Don't detect contact between the ship and other physics bodies
//    ship.physicsBody.contactTestBitMask = 0x0;
//    //3 Do detect collisions between the ship and the scene's outer edges.
//    ship.physicsBody.collisionBitMask = kSceneEdgeCategory;
//    //Note:You didn't need to set the ship's collisionBitMask before because only your ship and the scene had physics bodies. The default collisionBitMask of "all" was sufficient in that case. Since you'll be adding physics bodies to invaders next, setting your ship's collisionBitMask precisely ensures that your ship will only collide with the sides of the scene and won't also collide with invaders.
//    return ship;
//}
//! Boilerplate code for creating and adding text labels to a scene (Heads Up Display)
-(void)setupHud {
    SKLabelNode* scoreLabel = [SKLabelNode labelNodeWithFontNamed:@"Courier"];
    //1 Give the score label a name so you can find it later when you need to update the displayed score.
    scoreLabel.name = kScoreHudName;
    scoreLabel.fontSize = 15;
    //2 Color the score label green.
    scoreLabel.fontColor = [SKColor greenColor];
    scoreLabel.text = [NSString stringWithFormat:@"Score: %04u", 0];
    //3 Position the score label near the top left corner of the screen
    scoreLabel.position = CGPointMake(20 + scoreLabel.frame.size.width/2, self.size.height - (20 + scoreLabel.frame.size.height/2));
    [self addChild:scoreLabel];
    
    SKLabelNode* healthLabel = [SKLabelNode labelNodeWithFontNamed:@"Courier"];
    //4 Give the health label a name so you can reference it later when you need to update the displayed health
    healthLabel.name = kHealthHudName;
    healthLabel.fontSize = 15;
    //5 Color the health label red; the red and green indicators are common colors for these indicators in games, and they're easy to differentiate in the middle of furious gameplay
    healthLabel.fontColor = [SKColor redColor];
    // Sets the initial HUD text based on your ship's actual health value instead of a static value of 100
    healthLabel.text = [NSString stringWithFormat:@"Health: %.1f%%", self.shipHealth * 100.0f];
    //6 Position the health label near the top right corner of the screen
    healthLabel.position = CGPointMake(self.size.width - healthLabel.frame.size.width/2 - 20, self.size.height - (20 + healthLabel.frame.size.height/2));
    [self addChild:healthLabel];
}
//! Creates a rectangular colored sprite to represent a bullet and sets the name of the bullet so you can find it later in your scene.
-(SKNode*)makeBulletOfType:(BulletType)bulletType {
    SKNode* bullet;
    
    switch (bulletType) {
        case ShipFiredBulletType:
            bullet = [SKSpriteNode spriteNodeWithColor:[SKColor greenColor] size:kBulletSize];
            bullet.name = kShipFiredBulletName;
            
            // Code identifies ship-fired bullets as such and tells Sprite Kit to check for contact between ship-fired bullets and invaders, but that collisions should be ignored
            bullet.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:bullet.frame.size];
            bullet.physicsBody.dynamic = YES;
            bullet.physicsBody.affectedByGravity = NO;
            bullet.physicsBody.categoryBitMask = kShipFiredBulletCategory;
            bullet.physicsBody.contactTestBitMask = kInvaderCategory;
            bullet.physicsBody.collisionBitMask = 0x0;
            break;
        case InvaderFiredBulletType:
            bullet = [SKSpriteNode spriteNodeWithColor:[SKColor magentaColor] size:kBulletSize];
            bullet.name = kInvaderFiredBulletName;
            
            // Code identifies invader-fired bullets as such and tells Sprite Kit to check for contact between invader-fired bullets and your ship, and again, ignores the collision aspect
            bullet.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:bullet.frame.size];
            bullet.physicsBody.dynamic = YES;
            bullet.physicsBody.affectedByGravity = NO;
            bullet.physicsBody.categoryBitMask = kInvaderFiredBulletCategory;
            bullet.physicsBody.contactTestBitMask = kShipCategory;
            bullet.physicsBody.collisionBitMask = 0x0;
            break;
            
            // Note: In order for contact detection to work, the ship-fired bullets must be defined as dynamic by setting bullet.physicsBody.dynamic = YES. If not, Sprite Kit won't check for contact between these bullets and the static invaders as their definition is invader.physicsBody.dynamic = NO. Invaders are static because they aren't moved by the physics engine. Sprite Kit won't check for contact between two static bodies, so if you need to check for contact between two categories of physics bodies, at least one of the categories must have a dynamic physics body.
        default:
            bullet = nil;
            break;
    }
    
    return bullet;
}
#pragma mark - Scene Update

//Method gets called 60 times per second as the scene updates
- (void)update:(NSTimeInterval)currentTime
{
    if ([self isGameOver]) [self endGame];
    [self processContactsForUpdate:currentTime];
    [self processUserTapsForUpdate:currentTime];
    [self processUserMotionForUpdate:currentTime];
    [self moveInvadersForUpdate:currentTime];
    [self fireInvaderBulletsForUpdate:currentTime];
}

#pragma mark - Scene Update Helpers
//! This method will get invoked by update:
-(void)moveInvadersForUpdate:(NSTimeInterval)currentTime {
    //1 If it's not yet time to move, then exit the method. moveInvadersForUpdate: is invoked 60 times per second, but you don't want the invaders to move that often since the movement would be too fast for a normal person to se
    if (currentTime - self.timeOfLastMove < self.timePerMove) return;
    
    [self determineInvaderMovementDirection];
    
    //2 Recall that your scene holds all of the invaders as child nodes; you added them to the scene using addChild: in setupInvaders identifying each invader by its name property. Invoking enumerateChildNodesWithName:usingBlock: only loops over the invaders because they're named kInvaderName; this makes the loop skip your ship and the HUD. The guts of the block moves the invaders 10 pixels either right, left or down depending on the value of invaderMovementDirection.
    [self enumerateChildNodesWithName:kInvaderName usingBlock:^(SKNode *node, BOOL *stop) {
        switch (self.invaderMovementDirection) {
            case InvaderMovementDirectionRight:
                node.position = CGPointMake(node.position.x + 10, node.position.y);
                break;
            case InvaderMovementDirectionLeft:
                node.position = CGPointMake(node.position.x - 10, node.position.y);
                break;
            case InvaderMovementDirectionDownThenLeft:
            case InvaderMovementDirectionDownThenRight:
                node.position = CGPointMake(node.position.x, node.position.y - 10);
                break;
            InvaderMovementDirectionNone:
            default:
                break;
        }
    }];
    
    //3 Record that you just moved the invaders, so that the next time this method is invoked (1/60th of a second from now), the invaders won't move again till the set time period of one second has elapsed.
    self.timeOfLastMove = currentTime;
}

//! Evaluate accelerometer data from the phone to move the ship
-(void)processUserMotionForUpdate:(NSTimeInterval)currentTime {
    //1 Get the ship from the scene so you can move it
    SKSpriteNode* ship = (SKSpriteNode*)[self childNodeWithName:kShipName];
    //2 Get the accelerometer data from the motion manager.
    CMAccelerometerData* data = self.motionManager.accelerometerData;
    //3 If your device is oriented with the screen facing up and the home button at the bottom, then tilting the device to the right produces data.acceleration.x > 0, whereas tilting it to the left produces data.acceleration.x < 0. The check against 0.2 means that the device will be considered perfectly flat/no thrust (technically data.acceleration.x == 0) as long as it's close enough to zero (data.acceleration.x in the range [-0.2, 0.2]). There's nothing special about 0.2, it just seemed to work well for me. Little tricks like this will make your control system more reliable and less frustrating for users
    if (fabs(data.acceleration.x) > 0.2) {
        //4 How do you move the ship? You want small values to move the ship a little and large values to move the ship a lot. The answer is — physics, which you'll cover in the next section!
        
        //The line of code applies a force to the ship's physics body in the same direction as data.acceleration.x. The number 40.0 is an arbitrary value to make the ship's motion feel natural.
        [ship.physicsBody applyForce:CGVectorMake(40.0 * data.acceleration.x, 0)];
    }
}
//! Completely consumes the queue of taps at each invocation. Combined with the fact that fireShipBullets will not fire another bullet if one is already onscreen, this emptying of the queue means that extra or rapid-fire taps will be ignored. Only the first tap needed to fire a bullet will matter.
-(void)processUserTapsForUpdate:(NSTimeInterval)currentTime {
    //1 Loop over a copy of your tapQueue; it must be a copy because it’s possible that you’ll modify the original tapQueue while this code is running, and modifying an array while looping over it is a big no-no.
    for (NSNumber* tapCount in [self.tapQueue copy]) {
        if ([tapCount unsignedIntegerValue] == 1) {
            //2 If the queue entry is a single-tap, handle it. As the developer, you clearly know that you only handle single taps for now, but it’s best to be defensive against the possibility of double-taps (or other actions) later
            [self fireShipBullets];
        }
        //3 Remove the tap from the queue
        [self.tapQueue removeObject:tapCount];
    }
}
-(void)fireInvaderBulletsForUpdate:(NSTimeInterval)currentTime {
    SKNode* existingBullet = [self childNodeWithName:kInvaderFiredBulletName];
    //1 Only fire a bullet if one’s not already on-screen
    if (!existingBullet) {
        //2 Collect all the invaders currently on-screen
        NSMutableArray* allInvaders = [NSMutableArray array];
        [self enumerateChildNodesWithName:kInvaderName usingBlock:^(SKNode *node, BOOL *stop) {
            [allInvaders addObject:node];
        }];
        
        if ([allInvaders count] > 0) {
            //3 Select an invader at random
            NSUInteger allInvadersIndex = arc4random_uniform([allInvaders count]);
            SKNode* invader = [allInvaders objectAtIndex:allInvadersIndex];
            //4 Create a bullet and fire it from just below the selected invader
            SKNode* bullet = [self makeBulletOfType:InvaderFiredBulletType];
            bullet.position = CGPointMake(invader.position.x, invader.position.y - invader.frame.size.height/2 + bullet.frame.size.height / 2);
            //5 The bullet should travel straight down and move just off the bottom of the screen
            CGPoint bulletDestination = CGPointMake(invader.position.x, - bullet.frame.size.height / 2);
            //6 Fire off the invader’s bullet
            [self fireBullet:bullet toDestination:bulletDestination withDuration:2.0 soundFileName:@"InvaderBullet.wav"];
        }
    }
}
//! Drains the contact queue, calling handleContact: for each contact in the queue
-(void)processContactsForUpdate:(NSTimeInterval)currentTime {
    for (SKPhysicsContact* contact in [self.contactQueue copy]) {
        [self handleContact:contact];
        [self.contactQueue removeObject:contact];
    }
}
#pragma mark - Invader Movement Helpers
-(void)determineInvaderMovementDirection {
    //1 Since local variables accessed by a block are by default const (that is, they cannot be changed), you must qualify proposedMovementDirection with __block so that you can modify it in //2
    __block InvaderMovementDirection proposedMovementDirection = self.invaderMovementDirection;
    
    //2 Loop over all the invaders in the scene and invoke the block with the invader as an argument.
    [self enumerateChildNodesWithName:kInvaderName usingBlock:^(SKNode *node, BOOL *stop) {
        switch (self.invaderMovementDirection) {
            case InvaderMovementDirectionRight:
                //3 If the invader's right edge is within 1 point of the right edge of the scene, it's about to move offscreen. Set proposedMovementDirection so that the invaders move down then left. You compare the invader's frame (the frame that contains its content in the scene's coordinate system) with the scene width. Since the scene has an anchorPoint of (0, 0) by default, and is scaled to fill its parent view, this comparison ensures you're testing against the view's edges.
                if (CGRectGetMaxX(node.frame) >= node.scene.size.width - 1.0f) {
                    proposedMovementDirection = InvaderMovementDirectionDownThenLeft;
                    *stop = YES;
                }
                break;
            case InvaderMovementDirectionLeft:
                //4 If the invader's left edge is within 1 point of the left edge of the scene, it's about to move offscreen. Set proposedMovementDirection so that invaders move down then right.
                if (CGRectGetMinX(node.frame) <= 1.0f) {
                    proposedMovementDirection = InvaderMovementDirectionDownThenRight;
                    *stop = YES;
                }
                break;
            case InvaderMovementDirectionDownThenLeft:
                //5 If invaders are moving down then left, they've already moved down at this point, so they should now move left. How this works will become more obvious when you integrate determineInvaderMovementDirection with moveInvadersForUpdate:.
                proposedMovementDirection = InvaderMovementDirectionLeft;
                //! Reduces the time per move by 20% each time the invaders move down. This increases their speed by 25% (4/5 the move time means 5/4 the move speed)
                [self adjustInvaderMovementToTimePerMove:self.timePerMove * 0.8];
                *stop = YES;
                break;
            case InvaderMovementDirectionDownThenRight:
                //6 If the invaders are moving down then right, they've already moved down at this point, so they should now move right.
                proposedMovementDirection = InvaderMovementDirectionRight;
                //! Reduces the time per move by 20% each time the invaders move down. This increases their speed by 25% (4/5 the move time means 5/4 the move speed)
                [self adjustInvaderMovementToTimePerMove:self.timePerMove * 0.8];
                *stop = YES;
                break;
            default:
                break;
        }
    }];
    
    //7 If the proposed invader movement direction is different than the current invader movement direction, update the current direction to the proposed direction.
    if (proposedMovementDirection != self.invaderMovementDirection) {
        self.invaderMovementDirection = proposedMovementDirection;
    }
}
-(void)adjustInvaderMovementToTimePerMove:(NSTimeInterval)newTimePerMove {
    //1 Ignore bogus values — a value less than or equal to zero would mean infinitely fast or reverse movement, which doesn't make sense.
    if (newTimePerMove <= 0) return;
    
    //2 Set the scene's timePerMove to the given value. This will speed up the movement of invaders within moveInvadersForUpdate:. Record the ratio of the change so you can adjust the node's speed accordingly
    double ratio = self.timePerMove / newTimePerMove;
    self.timePerMove = newTimePerMove;
    
    [self enumerateChildNodesWithName:kInvaderName usingBlock:^(SKNode *node, BOOL *stop) {
        //3 Speed up the animation of invaders so that the animation cycles through its two frames more quickly. The ratio ensures that if the new time per move is 1/3 the old time per move, the new animation speed is 3 times the old animation speed. Setting the node's speed ensures that all of the node's actions run more quickly, including the action that animates between sprite frames.
        node.speed = node.speed * ratio;
    }];
}
#pragma mark - Bullet Helpers
-(void)fireBullet:(SKNode*)bullet toDestination:(CGPoint)destination withDuration:(NSTimeInterval)duration soundFileName:(NSString*)soundFileName {
    //1 Create an SKAction that moves the bullet to the desired destination and then removes it from the scene. This sequence executes the individual actions consecutively — the next action only takes place after the previous action has completed. Hence the bullet is removed from the scene only after it has been moved
    SKAction* bulletAction = [SKAction sequence:@[[SKAction moveTo:destination duration:duration],
                                                  [SKAction waitForDuration:3.0/60.0],
                                                  [SKAction removeFromParent]]];
    //2 Play the desired sound to signal that the bullet was fired. All sounds are included in the starter project and iOS knows how to find and load them
    SKAction* soundAction  = [SKAction playSoundFileNamed:soundFileName waitForCompletion:YES];
    //3 Move the bullet and play the sound at the same time by putting them in the same group. A group runs its actions in parallel, not sequentially.
    [bullet runAction:[SKAction group:@[bulletAction, soundAction]]];
    //4 Fire the bullet by adding it to the scene. This makes it appear onscreen and starts the actions
    [self addChild:bullet];
}

-(void)fireShipBullets {
    //SKNode* existingBullet = [self childNodeWithName:kShipFiredBulletName];
    
    //1 Only fire a bullet if there isn’t one currently on-screen. It’s a laser cannon, not a laser machine gun — it takes time to reload!
    //if (!existingBullet) removed to allow multiple shots
    if (true) {
        SKNode* ship = [self childNodeWithName:kShipName];
        SKNode* bullet = [self makeBulletOfType:ShipFiredBulletType];
        //2 Set the bullet’s position so that it comes out of the top of the ship.
        bullet.position = CGPointMake(ship.position.x, ship.position.y + ship.frame.size.height - bullet.frame.size.height / 2);
        //3 Set the bullet’s destination to be just off the top of the screen. Since the x coordinate is the same as that of the bullet’s position, the bullet will fly straight up
        CGPoint bulletDestination = CGPointMake(ship.position.x, self.frame.size.height + bullet.frame.size.height / 2);
        //4 Fire the bullet!
        [self fireBullet:bullet toDestination:bulletDestination withDuration:1.0 soundFileName:@"ShipBullet.wav"];
    }
    // Note: The decision in //1 to only allow one ship bullet on-screen at the same time is a gameplay decision, not a technical necessity. If your ship can fire thousands of bullets per minute, Space Invaders would be too easy. Part of the fun of your game is choosing your shots wisely and timing them to collide with invaders.
}
#pragma mark - User Tap Helpers
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    // Intentional no-op
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    // Intentional no-op
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    // Intentional no-op
}


-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch* touch = [touches anyObject];
    
    /*! Adds an entry to the tap queue. You don’t need a custom class to store the tap in the queue since all you need to know is that a tap occurred. Therefore, you can use any old object. Here, you use the integer 1 as a mnemonic for single tap (@1 is the new object-literal syntax that converts the literal 1 into an NSNumber object) */
    if (touch.tapCount == 1) [self.tapQueue addObject:@1];
}

#pragma mark - HUD Helpers
//! Update the Score
-(void)adjustScoreBy:(NSUInteger)points {
    self.score += points;
    SKLabelNode* score = (SKLabelNode*)[self childNodeWithName:kScoreHudName];
    score.text = [NSString stringWithFormat:@"Score: %04u", self.score];
}
//! Update the ship health
-(void)adjustShipHealthBy:(CGFloat)healthAdjustment {
    //1 merely ensures that the ship's health doesn't go negative
    self.shipHealth = MAX(self.shipHealth + healthAdjustment, 0);
    
    SKLabelNode* health = (SKLabelNode*)[self childNodeWithName:kHealthHudName];
    health.text = [NSString stringWithFormat:@"Health: %.1f%%", self.shipHealth * 100];
}

#pragma mark - Physics Contact Helpers
//! This method simply records the contact in your contact queue to handle later when update: executes
-(void)didBeginContact:(SKPhysicsContact *)contact {
    [self.contactQueue addObject:contact];
}
-(void)handleContact:(SKPhysicsContact*)contact {
    // Ensure you haven't already handled this contact and removed its nodes
    if (!contact.bodyA.node.parent || !contact.bodyB.node.parent) return;
    
    NSArray* nodeNames = @[contact.bodyA.node.name, contact.bodyB.node.name];
    if ([nodeNames containsObject:kShipName] && [nodeNames containsObject:kInvaderFiredBulletName]) {
        // Invader bullet hit a ship
        [self runAction:[SKAction playSoundFileNamed:@"ShipHit.wav" waitForCompletion:NO]];
        //1 Adjust the ship's health when it gets hit by an invader's bullet.
        [self adjustShipHealthBy:-0.334f];
        if (self.shipHealth <= 0.0f) {
            //2 If the ship's health is zero, remove the ship and the invader's bullet from the scene.
            [contact.bodyA.node removeFromParent];
            [contact.bodyB.node removeFromParent];
        } else {
            //3 If the ship's health is greater than zero, only remove the invader's bullet from the scene. Dim the ship's sprite slightly to indicate damage.
            SKNode* ship = [self childNodeWithName:kShipName];
            ship.alpha = self.shipHealth;
            if (contact.bodyA.node == ship) [contact.bodyB.node removeFromParent];
            else [contact.bodyA.node removeFromParent];
        }
    } else if ([nodeNames containsObject:kInvaderName] && [nodeNames containsObject:kShipFiredBulletName]) {
        // Ship bullet hit an invader
        [self runAction:[SKAction playSoundFileNamed:@"InvaderHit.wav" waitForCompletion:NO]];
        [contact.bodyA.node removeFromParent];
        [contact.bodyB.node removeFromParent];
        //4 When an invader is hit, add 100 points to the score.
        [self adjustScoreBy:100];
    }
}
//-(void)handleContact:(SKPhysicsContact*)contact {
//    //1 Ensure you haven't already handled this contact and removed its nodes
//    if (!contact.bodyA.node.parent || !contact.bodyB.node.parent) return;
//    
//    NSArray* nodeNames = @[contact.bodyA.node.name, contact.bodyB.node.name];
//    if ([nodeNames containsObject:kShipName] && [nodeNames containsObject:kInvaderFiredBulletName]) {
//        //2 If an invader bullet hits your ship, remove your ship and the bullet from the scene and play a sound.
//        [self runAction:[SKAction playSoundFileNamed:@"ShipHit.wav" waitForCompletion:NO]];
//        [contact.bodyA.node removeFromParent];
//        [contact.bodyB.node removeFromParent];
//    } else if ([nodeNames containsObject:kInvaderName] && [nodeNames containsObject:kShipFiredBulletName]) {
//        //3 If a ship bullet hits an invader, remove the invader and the bullet from the scene and play a different sound.
//        [self runAction:[SKAction playSoundFileNamed:@"InvaderHit.wav" waitForCompletion:NO]];
//        [contact.bodyA.node removeFromParent];
//        [contact.bodyB.node removeFromParent];
//    }
//}
#pragma mark - Game End Helpers
-(BOOL)isGameOver {
    //1 Get all invaders that remain in the scene.
    SKNode* invader = [self childNodeWithName:kInvaderName];
    
    //2 Iterate through the invaders to check if any invaders are too low.
    __block BOOL invaderTooLow = NO;
    [self enumerateChildNodesWithName:kInvaderName usingBlock:^(SKNode *node, BOOL *stop) {
        if (CGRectGetMinY(node.frame) <= kMinInvaderBottomHeight) {
            invaderTooLow = YES;
            *stop = YES;
        }
    }];
    
    //3 Get a pointer to your ship: if the ship's health drops to zero, then the player is considered dead and the player ship will be removed from the scene. In this case, you'd get a nil value indicating that there is no player ship.
    SKNode* ship = [self childNodeWithName:kShipName];
    
    //4 Return whether your game is over or not. If there are no more invaders, or an invader is too low, or your ship is destroyed, then the game is over.
    return !invader || invaderTooLow || !ship;
}

-(void)endGame {
    //1 End your game only once. Otherwise, you'll try to display the game over scene multiple times and this would be a definite bug.
    if (!self.gameEnding) {
        self.gameEnding = YES;
        //2 Stop accelerometer updates.
        [self.motionManager stopAccelerometerUpdates];
        //3 Show the GameOverScene. You can inspect GameOverScene.m for the details, but it's a basic scene with a simple "Game Over" message. The scene will start another game if you tap on it.
        GameOverScene* gameOverScene = [[GameOverScene alloc] initWithSize:self.size];
        [self.view presentScene:gameOverScene transition:[SKTransition doorsOpenHorizontalWithDuration:1.0]];
    }
}

@end
