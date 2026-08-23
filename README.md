# EXTERNAL IOS — Safe Build

Versão segura limitada ao próprio sandbox do aplicativo.

Inclui sistema de licença Keygen, interface escura/roxa, gerenciador de arquivos em `Documents` do próprio app, limpeza de `Caches`/temporários do próprio app, área de wallpapers e perfis locais.

## Base e licença

Este projeto contém adaptações inspiradas em componentes seguros do projeto [`YangJiiii/3105`](https://github.com/YangJiiii/3105), que é distribuído sob a GNU GPL v3. Partes relacionadas a exploit, anti-detection, acesso a containers de terceiros, sandbox escape, bypass ou modificação de outros apps **não são incluídas** nesta build.

As adaptações mantidas aqui ficam restritas ao sandbox do próprio aplicativo, com foco em navegação, organização de arquivos e limpeza local.

O texto integral da GNU GPL v3 deve ser mantido junto às partes derivadas compatíveis com essa licença.

## Build

O GitHub Actions gera `EXTERNAL_IOS_SAFE_UNSIGNED.ipa`.
