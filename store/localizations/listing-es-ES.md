# App Store listing — Español (es-ES)

App Store Connect → Notepad Classic → es-ES. Uploaded via the App Store Connect API for v1.2.9.
Limits: app name 30, subtitle 30, promotional text 170, keywords 100, description 4000.

## Subtitle (27/30)
Sin IA. Pestañas. Restaura.

## Promotional Text (153/170)
Bloc de notas de texto plano para Mac: sin IA, sin cuenta, sin nube. Pestañas y sesión restaurada conservan las notas sin guardar. UTF-8, EUC-KR, UTF-16.

## Keywords (88/100)
bloc de notas,editor de texto,texto plano,codificacion,pestañas,notas,editor,txt,unicode

## Description (1722/4000)
Un editor de texto plano rápido y privado para macOS. Para quien viene del Bloc de notas de Windows y para quien quiere las pestañas y la restauración que TextEdit no ofrece.

Sin IA. Sin cuenta. Sin nube obligatoria. Solo texto.

Restauración automática de la sesión
Cierra la aplicación con las pestañas abiertas, incluidas las notas sin guardar, y al abrirla de nuevo (también tras reiniciar) todo vuelve tal como estaba. En los ajustes eliges si cada inicio continúa la sesión anterior o empieza una nueva.

Varias pestañas
Trabaja con varios documentos en una ventana. Reordena arrastrando, cambia con Ctrl-Tab, y las pestañas sin guardar llevan un *.

Codificaciones
Abre y guarda en UTF-8, UTF-8 con BOM, EUC-KR y UTF-16 (LE/BE). Desde la barra de estado puedes reabrir con otra codificación o convertir el contenido, y avisa con claridad si algún carácter no se puede representar.

Ortografía y corrección
Usa los diccionarios del sistema de macOS y no necesita red. La corrección automática es opcional y puedes desactivar la revisión para extensiones de código o registros.

Vista previa opcional
Vista previa de .md y .html en paralelo o a pantalla completa. No ejecuta scripts. Las imágenes y el CSS remotos solo se cargan si los permites en esa pestaña.

Además
• Buscar y reemplazar en línea, con recuento de coincidencias y distinción de mayúsculas
• Resaltado de Markdown, JSON, XML, HTML y registros
• Imprimir, ir a una línea, insertar hora y fecha, ajuste de línea, zoom
• Varias ventanas, modo claro y oscuro, interfaz en 16 idiomas

Privacidad
Funciona en un sandbox completo, sin anuncios, y no recopila ningún dato. Solo usa la red en las pestañas donde permites imágenes remotas en la vista previa.

## What's New — v1.2.9 (1041/4000)
Correcciones al abrir y cerrar archivos.

• Abrir un documento desde el Finder ya no le añade el atributo de cuarentena de macOS. Antes, leer un archivo bastaba para añadirlo aunque no se escribiera nada, y después el Finder pedía comprobarlo cada vez que se abría, con esta app o con cualquier otra. Ahora abrir solo lee; el archivo se escribe únicamente al guardar.

• Un archivo que se negaba a abrirse ya se abre. Si una pestaña no podía restaurarse al iniciar, volver a abrir ese archivo solo cambiaba a la pestaña vacía sin leerlo.

• Un mismo archivo alcanzado por otra ruta —variante de mayúsculas o enlace simbólico— ya no se abre como dos pestañas que se sobrescriben entre sí.

• Escribir en una pestaña cuyo archivo no se pudo leer ya no omite el aviso previo a reemplazar el original.

• Cerrar la última pestaña cierra la ventana. Antes parecía que no ocurría nada.

• Abrir un archivo ya no deja una pestaña «Sin título» vacía al lado.

• Los errores al guardar explican qué ha fallado en lugar de pedir siempre una ubicación.
