# Patched confirmation

Use only after verify.sh PASS for every listed site.

## EN
**Subject:** Done: {{ADVISORY_NAME}} update applied to {{site_or_sites}}

Hi {{client_name}},

{{site_or_sites}} now run PHP {{new_version}}, which includes the fix for
{{CVES}}. We applied it on {{patch_datetime}} and confirmed it is active.

We also reviewed the site for signs of misuse during the exposure window:
{{compromise_check_result}}.

{{optional_next_steps}}

No action is needed from you. Thanks for your patience.

{{your_name}}

## ES
**Asunto:** Listo: actualización de {{ADVISORY_NAME}} aplicada en {{site_or_sites}}

Hola {{client_name}}:

{{site_or_sites}} ya funciona con PHP {{new_version}}, que incluye la corrección de
{{CVES}}. La aplicamos el {{patch_datetime}} y confirmamos que está activa.

También revisamos el sitio en busca de señales de uso indebido durante el periodo de
exposición: {{compromise_check_result}}.

{{optional_next_steps}}

No necesita hacer nada. Gracias por su paciencia.

{{your_name}}
