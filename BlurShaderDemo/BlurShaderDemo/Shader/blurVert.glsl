attribute vec4 position;
attribute vec2 texcoord;
varying vec2 vTexcoord;

void main()
{
    gl_Position = position;
    vTexcoord = texcoord;
}
