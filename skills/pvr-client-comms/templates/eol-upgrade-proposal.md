# End-of-life upgrade proposal

## EN
**Subject:** Action needed: {{site}} runs an unsupported PHP version

Hi {{client_name}},

{{site}} runs PHP {{current_version}}, which reached end of life and will **not**
receive a fix for the critical vulnerability {{CVES}}. Updates were released only
for PHP {{FIXED_VERSIONS}}.

What we did today to reduce risk: {{containment_applied}}. This lowers exposure but
does not remove it.

Recommended: move the site to PHP {{target_branch}}.
- Steps: staging copy, compatibility check and plugin/theme updates, testing,
  switch, 48-hour rollback window.
- Estimated time: {{estimate_time}}. Investment: {{estimate_price}}.
- Possible impacts: {{known_incompatibilities_or_none}}.

Please reply to approve so we can schedule it this week.

{{your_name}}

## ES
**Asunto:** Acción requerida: {{site}} usa una versión de PHP sin soporte

Hola {{client_name}}:

{{site}} funciona con PHP {{current_version}}, que llegó al fin de su vida útil y
**no** recibirá corrección para la vulnerabilidad crítica {{CVES}}. Las
actualizaciones solo se publicaron para PHP {{FIXED_VERSIONS}}.

Lo que hicimos hoy para reducir el riesgo: {{containment_applied}}. Esto reduce la
exposición, pero no la elimina.

Recomendación: migrar el sitio a PHP {{target_branch}}.
- Pasos: copia de prueba (staging), revisión de compatibilidad y actualización de
  plugins/temas, pruebas, cambio y 48 horas de respaldo para revertir.
- Tiempo estimado: {{estimate_time}}. Inversión: {{estimate_price}}.
- Posibles impactos: {{known_incompatibilities_or_none}}.

Favor de responder con su aprobación para programarlo esta semana.

{{your_name}}
