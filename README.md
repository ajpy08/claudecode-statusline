# claudecode-statusline

Status line para Claude Code: una sola línea con la ruta, la rama de git, el contexto usado, la cuota de uso restante, las líneas de código tocadas y el modelo.

```
~/Projects/mi-repo 🌿 (main) | ⚡ ████████░░░░░░░░░░░░ ctx 42% | left 5h:91% ↻lun 13:51  7d:49% ↻mié 19:24 | +120 -35 | 🤖 Sonnet 5.5
```

## Qué muestra

| Segmento | Qué es | De dónde sale |
|---|---|---|
| `~/Projects/mi-repo` | Directorio de trabajo, con `~` por el home. El nombre del repo va en amarillo y hace de último tramo de la ruta, sin repetirse | `workspace.current_dir` + `git rev-parse --show-toplevel` |
| `🌿 (main)` | Rama actual | `git symbolic-ref` |
| `ctx 42%` | Cuánto de la ventana de contexto de la conversación está usado, con barra de 20 bloques en degradado verde → rojo. Antes de la primera respuesta de la sesión muestra `ctx --%` | `context_window.used_percentage` |
| `left 5h:91% ↻lun 13:51` | Lo que **queda** de la cuota de 5 horas y de la semanal (`7d`), y el día y hora en que se reinicia cada una | `rate_limits.five_hour` y `rate_limits.seven_day` |
| `+120 -35` | Líneas agregadas y quitadas en la sesión | `cost.total_lines_added` / `cost.total_lines_removed` |
| `🤖 Sonnet 5.5` | Modelo en uso | `model.display_name` |

### Colores

- **Contexto:** verde por debajo de 70 %, amarillo desde 70 %, rojo desde 90 % (con emoji 🟢 / ⚡ / 🔥 / 🚨 según el nivel).
- **Cuota restante:** verde con más de 30 %, amarillo entre 30 % y 10 %, rojo con 10 % o menos.

## Requisitos

- Claude Code con soporte de `statusLine` de tipo `command`.
- `bash`, `jq` y `git`.
- Un terminal con color verdadero (24 bits) para el degradado de la barra.
- macOS: el script usa `date -r <epoch>` para dar formato a la hora de reinicio de la cuota. En Linux hay que cambiarlo por `date -d @<epoch>`.

## Instalación

1. Clona el repo y deja el script ejecutable:

   ```sh
   git clone git@github.com:ajpy08/claudecode-statusline.git
   chmod +x claudecode-statusline/statusline.sh
   ```

2. Apunta Claude Code al script en `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "/ruta/absoluta/a/claudecode-statusline/statusline.sh"
     }
   }
   ```

3. Abre una sesión nueva de Claude Code.

## Cómo funciona

Claude Code ejecuta el comando cada vez que cambia algo en la sesión y le pasa un JSON por la entrada estándar. El script lo lee con `jq`, arma la línea y la imprime. No guarda archivos ni consulta el Keychain ni hace llamadas de red.

Para probarlo a mano, sin abrir Claude Code:

```sh
echo '{"model":{"display_name":"Sonnet 5.5"},"cwd":"'"$PWD"'","context_window":{"used_percentage":42}}' | ./statusline.sh
```

## Qué pasa cuando falta un dato

Cada segmento se omite o se degrada solo, sin romper la línea:

- Sin `used_percentage` (sesión nueva o recién limpiada con `/clear`): `ctx --%` con la barra vacía.
- Sin `rate_limits` (claves de API, versiones que no lo mandan o antes de la primera respuesta): el bloque `left …` no aparece.
- Fuera de un repo de git: se muestra la ruta completa y sin rama.

## Notas

- La cuota depende de que Claude Code envíe los campos `rate_limits`. Si el bloque `left …` no aparece en tu versión, ese es el motivo más probable.
- Se quitó a propósito el costo en dólares: con una suscripción es un cálculo a precio de API, no lo que se paga.
