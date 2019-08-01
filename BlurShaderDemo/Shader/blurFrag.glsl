precision mediump float;

uniform sampler2D image;
uniform float textureWidth;
uniform float textureHeight;
uniform float radius;
varying vec2 vTexcoord;

//uniform float quality; // 半徑切幾等份
//uniform float directions; // 圈切幾等份
//const float Pi2 = 6.28318530718;//pi * 2

void main()
{
    lowp vec4 sum = vec4(0.0);
    vec2 texSize = vec2(textureWidth, textureHeight) ;
    // 用Box的方式
    vec2 boxSize = vec2( radius*2.0 + 1.0, radius*2.0 + 1.0);
    vec4 color = texture2D( image, vTexcoord);
    for( float x=-radius; x<=radius; x+=1.0 ) {
        for( float y=-radius; y<=radius; y+=1.0 ) {
            // texture coordinate 計算時是用 0~1，所以 offset 要計算時，也要轉換成 0~1 的比例
            vec2 offset = vec2(x/textureWidth,y/textureHeight);
            color += texture2D( image, vTexcoord + offset );
        }
    }
    color /= (boxSize.x * boxSize.y);
    
    gl_FragColor =  color;
}
