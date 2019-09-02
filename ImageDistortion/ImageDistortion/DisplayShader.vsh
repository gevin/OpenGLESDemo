attribute vec4 position;
attribute vec4 inputTextureCoordinate;
uniform float angle;
float PI = 3.1415926535897932384626433832795;

varying vec2 textureCoordinate;

void main()
{
    float initialAngle = angle/180.0;
    float curAngle = initialAngle + position.y/0.1; // 目前 y 轉成對應的角度。整個 framebuffer 高的 0.1 為一個週期
    float radius = 0.05;
    float radian = PI * curAngle;
    gl_Position = vec4( position.x + (radius * sin(radian)), position.y, position.z, position.w ); //position;//   //     
    textureCoordinate = inputTextureCoordinate.xy;
}
