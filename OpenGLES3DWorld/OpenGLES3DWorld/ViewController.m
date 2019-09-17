//
//  ViewController.m
//  OpenGLESDemo
//
//  Created by wangyang on 15/8/28.
//  Copyright (c) 2015年 wangyang. All rights reserved.
//

#import "ViewController.h"
#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>

typedef struct Vector3{
    GLfloat x;
    GLfloat y;
    GLfloat z;
}Vector3;

typedef struct SphereVector3{
    GLfloat r;
    GLfloat theta;
    GLfloat phi;
}SphereVector3;

Vector3 vec3FromSphereVec3( SphereVector3 sphereVec3, Vector3 pos ) {
    Vector3 vec3;
    vec3.x = sphereVec3.r * sin(M_PI * (sphereVec3.theta/180.0)) * sin(M_PI * (sphereVec3.phi/180.0));
    vec3.y = sphereVec3.r * cos(M_PI * (sphereVec3.theta/180.0));
    vec3.z = sphereVec3.r * sin(M_PI * (sphereVec3.theta/180.0)) * cos(M_PI * (sphereVec3.phi/180.0));
    vec3.x += pos.x;
    vec3.y += pos.y;  
    vec3.z += pos.z;  
    
    return vec3;
}

SphereVector3 sphereVec3FromVec3( Vector3 vec3 ) {
    SphereVector3 sphereVec3;
    
    sphereVec3.r = sqrt( (vec3.x * vec3.x) + (vec3.y * vec3.y) + (vec3.z * vec3.z));
    sphereVec3.theta = acos( vec3.y / sphereVec3.r );
    sphereVec3.phi = atanf(vec3.z/vec3.x);
    return sphereVec3;
}


@interface ViewController () <CLLocationManagerDelegate>
@property (assign, nonatomic) GLKMatrix4 projectionMatrix; // 投影矩阵
@property (assign, nonatomic) GLKMatrix4 cameraMatrix; // 观察矩阵
@property (assign, nonatomic) GLKMatrix4 planeMatrix;
@property (assign, nonatomic) GLKMatrix4 modelMatrix1; // 第一个矩形的模型变换
@property (assign, nonatomic) GLKMatrix4 modelMatrix2; // 第二个矩形的模型变换
@property (retain, nonatomic) CMMotionManager *motionManager;
@property (retain, nonatomic) CLLocationManager *locationManager;

@end

@implementation ViewController
{
    GLfloat deltaAngle;
    GLfloat step;
    SphereVector3 cameraLook;
    Vector3 cameraFront;
    Vector3 cameraPosition;
    Vector3 cameraUp;
    double deviceAngle;
    NSLock *lock;
    
    NSOperationQueue *gyroQueue;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    gyroQueue = [[NSOperationQueue alloc] init];
    
    // 使用透视投影矩阵
    float aspect = self.view.frame.size.width / self.view.frame.size.height;
    self.projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(90), aspect, 0.1, 100.0);
    
    // 设置摄像机在 0，0，2 坐标，看向 0，0，0点。Y轴正向为摄像机顶部指向的方向
    self.cameraMatrix = GLKMatrix4MakeLookAt(0, 0, 2, 0, 0, 0, 0, 1, 0);
    self.planeMatrix = GLKMatrix4Identity;
    // 先初始化矩形1的模型矩阵为单位矩阵
    self.modelMatrix1 = GLKMatrix4Identity;
    // 先初始化矩形2的模型矩阵为单位矩阵
    self.modelMatrix2 = GLKMatrix4Identity;
    
    deltaAngle = 5;
    step = 0.25;
    
    cameraPosition = (Vector3){2,0.5,3};
    cameraUp = (Vector3){0,1,0};
    cameraFront = (Vector3){0,0,0};
    
    cameraLook = (SphereVector3){1,90,0};
    cameraFront = vec3FromSphereVec3(cameraLook, cameraPosition);
    
    [self startMotion];
    [self startLocation];
}

- (void)viewDidDisappear:(BOOL)animated {
    // 该界面消失时一定要停止，不然会一直调用消耗内存
    [self.motionManager stopDeviceMotionUpdates]; // 停止所有的设备
    [self stopMotion];
    [self stopLocation];
}

#pragma mark - Update Delegate

- (void)update {
    [super update];
    float varyingFactor = (sin(self.elapsedTime) + 1) / 2.0; // 0 ~ 1
    
    [lock lock];
    // ios 水平儀 0從平面開始，往上是正
    // 但 spherical 座標，0是從正上面開始，往下到水平視角是 90，跟 ios 水平儀的座標相反
    // 所以下面要做轉換先是方向變換，所以加個 - 號，然後兩者 0 度的起點差 90度，所以再加上 90
    double levelAngle = -[self getTheta] + 90;
    cameraLook.theta = levelAngle;
    cameraFront = vec3FromSphereVec3(cameraLook, cameraPosition);    
    self.cameraMatrix = GLKMatrix4MakeLookAt( cameraPosition.x, cameraPosition.y, cameraPosition.z, cameraFront.x, cameraFront.y, cameraFront.z, cameraUp.x, cameraUp.y, cameraUp.z); // * (varyingFactor + 1)
    [lock unlock];
    
    GLKMatrix4 translateMatrix1 = GLKMatrix4MakeTranslation(4, 0, 5);
    GLKMatrix4 rotateMatrix1 = GLKMatrix4MakeRotation(varyingFactor * M_PI * 2, 0, 1, 0);
    self.modelMatrix1 = GLKMatrix4Multiply(translateMatrix1, rotateMatrix1);
    
//    GLKMatrix4 translateMatrix2 = GLKMatrix4MakeTranslation(0.7, 0, 0);
//    GLKMatrix4 rotateMatrix2 = GLKMatrix4MakeRotation(varyingFactor * M_PI, 0, 0, 1);
//    self.modelMatrix2 = GLKMatrix4Multiply(translateMatrix2, rotateMatrix2);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [super glkView:view drawInRect:rect];

    
    GLuint projectionMatrixUniformLocation = glGetUniformLocation(self.shaderProgram, "projectionMatrix");
    glUniformMatrix4fv(projectionMatrixUniformLocation, 1, 0, self.projectionMatrix.m);
    
    GLuint cameraMatrixUniformLocation = glGetUniformLocation(self.shaderProgram, "cameraMatrix");
    glUniformMatrix4fv(cameraMatrixUniformLocation, 1, 0, self.cameraMatrix.m);
    
    GLuint modelMatrixUniformLocation = glGetUniformLocation(self.shaderProgram, "modelMatrix");

    glUniformMatrix4fv(modelMatrixUniformLocation, 1, 0, self.planeMatrix.m);
    // draw plane
    [self drawPlane];
    
    // 绘制第一个矩形
    glUniformMatrix4fv(modelMatrixUniformLocation, 1, 0, self.modelMatrix1.m);
    [self drawRectangle];
    
//    // 绘制第二个矩形
//    glUniformMatrix4fv(modelMatrixUniformLocation, 1, 0, self.modelMatrix2.m);
//    [self drawRectangle];
}


#pragma mark - Draw Many Things

- (void)drawPlane {    
    for (int i=0; i<80; i++) {
        [self bindAttribsForLine:i];
        glDrawArrays(GL_LINES, 0, 2);
    }
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

- (void)drawRectangle {
    static GLfloat triangleData[36] = {
        -0.5,    1.0f,  0,  1,  0,  0, // x, y, z, r, g, b,每一行存储一个点的信息，位置和颜色
        -0.5f,   0.0f,  0,  0,  1,  0,
         0.5f,  -0.0f,  0,  0,  0,  1,
         0.5,   -0.0f,  0,  0,  0,  1,
         0.5f,   1.0f,  0,  0,  1,  0,
        -0.5f,   1.0f,  0,  1,  0,  0,
    };
    [self bindAttribs:triangleData];
    glDrawArrays(GL_TRIANGLES, 0, 6);
}

#pragma mark - Button Action

- (IBAction)btnLookUp:(id)sender {
    [lock lock];
    if(cameraLook.theta > 30 ) {
        cameraLook.theta = (GLfloat)((int)(cameraLook.theta - deltaAngle) % 360);
        if(cameraLook.theta < 30) {
            cameraLook.theta = 30.0;
        }
        cameraFront = vec3FromSphereVec3(cameraLook, cameraPosition);
    }
    [lock unlock];
}

- (IBAction)btnLookDown:(UIButton *)sender {
    [lock lock];
    if(cameraLook.theta < 150 ) {
        cameraLook.theta = (GLfloat)((int)(cameraLook.theta + deltaAngle) % 360);
        if(cameraLook.theta > 150) {
            cameraLook.theta = 150.0;
        }
        cameraFront = vec3FromSphereVec3(cameraLook, cameraPosition);
    }
    [lock unlock];
}

- (IBAction)btnLookRight:(UIButton *)sender {
    [lock lock];
    cameraLook.phi = (GLfloat)((int)(cameraLook.phi - deltaAngle) % 360);
    //printf("look theta:%.03f, phi:%.03f\n", cameraLook.theta, cameraLook.phi);
    cameraFront = vec3FromSphereVec3(cameraLook, cameraPosition);
    //printf("front x:%.02f , y:%.02f , z:%.02f\n\n", cameraFront.x, cameraFront.y, cameraFront.z);
    [lock unlock];
}

- (IBAction)btnLookLeft:(UIButton *)sender {
    [lock lock];
    cameraLook.phi = (GLfloat)((int)(cameraLook.phi + deltaAngle) % 360);
    //printf("look theta:%.03f, phi:%.03f\n", cameraLook.theta, cameraLook.phi);
    cameraFront = vec3FromSphereVec3(cameraLook, cameraPosition);
    //printf("front x:%.02f , y:%.02f , z:%.02f\n\n", cameraFront.x, cameraFront.y, cameraFront.z);
    [lock unlock];
}

#pragma mark -

- (IBAction)btnMoveForward:(UIButton *)sender {
    [lock lock];
    SphereVector3 moveVec = (SphereVector3){step,cameraLook.theta,cameraLook.phi}; 
    cameraPosition = vec3FromSphereVec3(moveVec, cameraPosition);
    cameraFront = vec3FromSphereVec3(cameraLook, cameraPosition);
    [lock unlock];
}

- (IBAction)btnMoveBack:(UIButton *)sender {
    [lock lock];
    SphereVector3 moveVec = (SphereVector3){step,cameraLook.theta,cameraLook.phi + 180};
    cameraPosition = vec3FromSphereVec3(moveVec, cameraPosition);
    cameraFront = vec3FromSphereVec3(cameraLook, cameraPosition);
    [lock unlock];
}

- (IBAction)btnMoveRight:(UIButton *)sender {
    [lock lock];
    SphereVector3 moveVec = (SphereVector3){step,cameraLook.theta,cameraLook.phi + 270};
    cameraPosition = vec3FromSphereVec3(moveVec, cameraPosition);
    cameraFront = vec3FromSphereVec3(cameraLook, cameraPosition);
    [lock unlock];
}

- (IBAction)btnMoveLeft:(UIButton *)sender {
    [lock lock];
    SphereVector3 moveVec = (SphereVector3){step,cameraLook.theta,cameraLook.phi + 90};
    cameraPosition = vec3FromSphereVec3(moveVec, cameraPosition);
    cameraFront = vec3FromSphereVec3(cameraLook, cameraPosition);
    [lock unlock];
}

- (IBAction)btnReset:(id)sender {
    [lock lock];
    cameraLook = (SphereVector3){1,90,0};
    cameraFront = vec3FromSphereVec3(cameraLook, cameraPosition);
    [lock unlock];
}

#pragma mark - Location

- (void)startLocation
{
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    self.locationManager.distanceFilter = kCLLocationAccuracyNearestTenMeters;
    self.locationManager.delegate = self;
    
    //startLocation = nil
//    [self.locationManager stopUpdatingLocation];
//    [self.locationManager requestAlwaysAuthorization];
//    [self.locationManager startUpdatingLocation];
    [self.locationManager startUpdatingHeading];
}

- (void)stopLocation {
//    [self.locationManager stopUpdatingLocation];
    [self.locationManager stopUpdatingHeading];
}

- (void)locationManager:(CLLocationManager *)manager
       didUpdateHeading:(CLHeading *)newHeading 
{
    // 0 ~ 359.9
    deviceAngle = newHeading.trueHeading; // convert from degrees to radians
//    NSLog(@"angle: %.04f", deviceAngle);
    [lock lock];
    cameraLook.phi = fabs(360.0 - deviceAngle);
    cameraFront = vec3FromSphereVec3(cameraLook, cameraPosition);
    [lock unlock];
}

#pragma mark - gyro

//- (void)gyroPush
//{
//    // 1.初始化运动管理对象
//    self.motionManager = [[CMMotionManager alloc] init];
//    // 2.判断陀螺仪是否可用
//    if (![self.motionManager isDeviceMotionAvailable]) {
//        NSLog(@"水平儀不可用");
//        return;
//    }
////    if (![self.motionManager isMagnetometerAvailable]) {
////        NSLog(@"磁力針不可用");
////        return;
////    }
//    // 3.设置陀螺仪更新频率，以秒为单位
//    self.motionManager.gyroUpdateInterval = 0.1;
//    // 4.开始实时获取
////    [self.motionManager startGyroUpdatesToQueue:[[NSOperationQueue alloc] init] withHandler:^(CMGyroData * _Nullable gyroData, NSError * _Nullable error) {
////        //获取陀螺仪数据
////        CMRotationRate rotationRate = gyroData.rotationRate;
////        NSLog(@"加速度 == x:%f, y:%f, z:%f", rotationRate.x, rotationRate.y, rotationRate.z);
////        
////        gyroData.
////        
////    }];
//    
//    [self.motionManager startDeviceMotionUpdatesToQueue:gyroQueue withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
//        // Gravity 获取手机的重力值在各个方向上的分量，根据这个就可以获得手机的空间位置，倾斜角度等
//        double gravityX = motion.gravity.x;
//        double gravityY = motion.gravity.y;
//        double gravityZ = motion.gravity.z;
//        
//        // 获取手机的倾斜角度(zTheta是手机与水平面的夹角， xyTheta是手机绕自身旋转的角度)：
//        double zTheta = atan2(gravityZ,sqrtf(gravityX * gravityX + gravityY * gravityY)) / M_PI * 180.0;
//        double xyTheta = atan2(gravityX, gravityY) / M_PI * 180.0;
//        
//        NSLog(@"手机与水平面的夹角 --- %.4f, 手机绕自身旋转的角度为 --- %.4f", zTheta, xyTheta);
//    }];
//    
////    [self.motionManager startMagnetometerUpdatesToQueue:gyroQueue withHandler:^(CMMagnetometerData * _Nullable magnetometerData, NSError * _Nullable error) {
////        
////        NSLog(@"X = %f,Y = %f,Z = %f",magnetometerData.magneticField.x,magnetometerData.magneticField.y,magnetometerData.magneticField.z);
//////        NSString *info = [NSString stringWithFormat:@"磁北：%.0f,真北：%.0f \n偏移：%.0f \nx:%.1f y:%.1f z:%.1f",
//////                                     userLocation.heading.magneticHeading,userLocation.heading.trueHeading,userLocation.heading.headingAccuracy,userLocation.heading.x,userLocation.heading.y,userLocation.heading.z];
////    }];
//    
//}

- (void)startMotion
{
    // 1.初始化运动管理对象
    self.motionManager = [[CMMotionManager alloc] init];
    // 2.判断陀螺仪是否可用
    if (![self.motionManager isDeviceMotionAvailable]) {
        NSLog(@"陀螺仪不可用");
        return;
    }
    // 3.开始更新
    [self.motionManager startDeviceMotionUpdates];
}

- (void)stopMotion
{
    [self.motionManager stopDeviceMotionUpdates];
}

//在需要的时候获取值
- (double)getTheta
{
    CMAcceleration gravity = self.motionManager.deviceMotion.gravity;
    // Gravity 获取手机的重力值在各个方向上的分量，根据这个就可以获得手机的空间位置，倾斜角度等
    
    // 获取手机的倾斜角度(zTheta是手机与水平面的夹角， xyTheta是手机绕自身旋转的角度)：
    double zTheta = atan2(gravity.z,sqrtf(gravity.x * gravity.x + gravity.y * gravity.y)) / M_PI * 180.0;
    //NSLog(@"手机与水平面的夹角 --- %.4f",zTheta);
    return zTheta;
}

@end
