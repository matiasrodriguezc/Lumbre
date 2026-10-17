# Genera web/assets/img/og.png (1200x630) con la red dormida, la neurona, el wordmark y el tagline.
# Uso: python3 web/scripts/og.py <raíz del repo>. Lo llama sync-assets.sh. Requiere Pillow.
import os, re, sys
from PIL import Image, ImageDraw, ImageFont
root = sys.argv[1]
W, H, S = 1200, 630, 2
img = Image.new('RGB', (W*S, H*S), '#E3E3DF'); d = ImageDraw.Draw(img)
svg = open(f'{root}/web/assets/img/red-dormida.svg').read()
def polys(dstr):
    for sub in re.split(r'(?=M)', dstr):
        pts = [(float(x), float(y)) for x, y in re.findall(r'(-?[\d.]+)[ ,](-?[\d.]+)', sub)]
        if len(pts) > 2: yield pts
for cls, color in (('n-link', '#D3D3CE'), ('n-dormant', '#D9D9D4')):
    for m in re.finditer(r'<path class="%s" d="([^"]+)"' % cls, svg):
        for pts in polys(m.group(1)):
            d.polygon([(x*S, y*S) for x, y in pts], fill=color)
fade = Image.new('L', (W*S, H*S), 0); fd = ImageDraw.Draw(fade)
for y in range(H*S):
    fd.line([(0, y), (W*S, y)], fill=int(255*max(0, min(1, (y/(H*S)-0.25)/0.45))))
img = Image.composite(Image.new('RGB', (W*S, H*S), '#E3E3DF'), img, fade); d = ImageDraw.Draw(img)
mark = open(f'{root}/web/assets/img/lumbre-mark.svg').read()
pts = [(float(x), float(y)) for x, y in re.findall(r'(-?[\d.]+) (-?[\d.]+)', re.search(r'd="([^"]+)"', mark).group(1))]
ox, oy, k = 80, 150, 1.25
d.polygon([((ox+x*k)*S, (oy+y*k)*S) for x, y in pts], fill='#0E0E10')
font = f'{root}/ios/Packages/LumbreDesign/Sources/LumbreDesign/Resources/Fraunces.ttf'
def fr(size):
    f = ImageFont.truetype(font, size*S); f.set_variation_by_axes([144, 600, 100, 0]); return f
big = fr(120); x0, y0 = 400, 130
d.text((x0*S, y0*S), 'Lumbre', font=big, fill='#0E0E10')
box = d.textbbox((x0*S, y0*S), 'Lumbre', font=big)
r = 9*S
d.ellipse([box[2]+5*S, box[3]-2*r, box[2]+5*S+2*r, box[3]], fill='#FF3EA5')
t = fr(54)
d.text((80*S, 380*S), 'El método para tener ideas,', font=t, fill='#0E0E10')
d.text((80*S, 446*S), 'en tu bolsillo.', font=t, fill='#0E0E10')
sys_font = '/System/Library/Fonts/SFNS.ttf'
sf = ImageFont.truetype(sys_font, 26*S) if os.path.exists(sys_font) else ImageFont.load_default()
d.text((80*S, 540*S), 'Anotate en la fila y probá la demo', font=sf, fill='#5A5A5E')
img.resize((W, H), Image.LANCZOS).save(f'{root}/web/assets/img/og.png', optimize=True)
