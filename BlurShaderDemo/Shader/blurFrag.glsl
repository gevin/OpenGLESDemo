precision mediump float;

uniform sampler2D image;
uniform float textureWidth;
uniform float textureHeight;
uniform float radius;
varying vec2 vTexcoord;

uniform float quality; // 半徑切幾等份
uniform float directions; // 圈切幾等份
const float Pi2 = 6.28318530718;//pi * 2


void main()
{
    lowp vec4 sum = vec4(0.0);
    vec2 size = vec2(textureWidth, textureHeight) ;
    // texture coordinate 計算時是用 0~1，所以 radius 要計算時，也要轉換成 0~1 的比例
    vec2 vradius = radius/size.xy; 
    vec4 color = texture2D( image, vTexcoord);
    for( float degree=0.0; degree<Pi2; degree += Pi2/directions ) {
        for( float i=1.0 ; i<=quality; i+=1.0 ) {
            color += texture2D( image, vTexcoord + vec2(cos(degree),sin(degree)) * (vradius * (i/quality)) );
        }
    }
    // 最後把 color / quality * directions + 1.0
    // 因為顏色一直累加，可能會超過 255，那就會變全白，總共抓了 quality * directions 這麼多個像素的顏色來累加
    // 每個像素的權重就是只有 quality * directions + 1.0， 1.0 是圓心
    color /= quality * directions + 1.0;
    gl_FragColor =  color;
}
