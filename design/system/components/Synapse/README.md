# Synapse
La sinapsis: dos terminales enfrentadas con la estrella de la chispa en el hueco. Es la ilustración del momento chispa.

- Va entre las dos neuronas de la SparkCard (56–64pt de ancho), en el reveal y en la tarjeta para compartir. En ningún otro lado.
- Estados: `lit` (encendida, con la estrella `spark`), `reaching` (las terminales salen y viaja el impulso `info-text`, sin estrella) y `apart` (en espera, terminales cortas).
- `full` dibuja las dos neuronas del logo enfrentadas: para la chispa, el reveal y la tarjeta para compartir. Sin `full`, solo las terminales (conectores chicos).
- Sin estrella cuando ya hay otro rosa protagonista en pantalla (por ejemplo, el onboarding con "Empezar").
- Terminales en `ink`, así funciona en los dos temas. Es decorativa: se oculta a VoiceOver/TalkBack; el par de neuronas ya se lee como texto.
- iOS: `Synapse(.lit)` en LumbreDesign. Forma generada desde `identidad/generar.py`.
