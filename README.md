# Translator App

O **Translator App** é uma aplicação em Dart voltada para a realização de traduções. Este guia foi elaborado para que você configure rapidamente o ambiente, crie um alias global chamado `translator` e defina a variável de ambiente com o token do Gemini.

## Pré-requisitos

- **Dart SDK**  
  Certifique-se de que o [Dart](https://dartbrasil.dev/get-dart) está instalado.  
  Para verificar, execute:
  ```sh
  dart --version
  ```

- **Token do Gemini**  
  Você precisa de um token válido para acessar os recursos de IA do Google.  
  **Como obter a Gemini Key:**  
  Acesse o site [aqui](https://aistudio.google.com/apikey), faça login com sua conta Google e siga as instruções para gerar sua chave.  
  Em seguida, configure a variável de ambiente `GEMINI_TOKEN` com o valor da sua chave.

## Configuração do Token do Gemini

### Linux/macOS

1. Abra seu arquivo de configuração do shell (por exemplo, `~/.bashrc` ou `~/.zshrc`).
2. Adicione a linha abaixo, substituindo `seu_token_aqui` pelo token obtido:
   ```sh
   export GEMINI_TOKEN=seu_token_aqui
   ```
3. Recarregue as configurações:
   ```sh
   source ~/.bashrc   # ou source ~/.zshrc
   ```

### Windows

1. Em um terminal (CMD ou PowerShell), defina a variável de ambiente permanentemente:
   ```bat
   setx GEMINI_TOKEN "seu_token_aqui"
   ```
2. Reinicie o terminal para que a alteração tenha efeito.

## Criação do Alias `translator`

Para facilitar a execução do app, crie um alias que invoque o script Dart localizado em `bin/translator.dart`.

### Linux/macOS (sh/bash)

1. Abra seu arquivo de configuração do shell (por exemplo, `~/.bashrc` ou `~/.zshrc`).
2. Adicione a seguinte linha, substituindo `/caminho/para/seu/projeto` pelo caminho real do repositório:
   ```sh
   alias translator='dart /caminho/para/seu/projeto/bin/translator.dart'
   ```
3. Recarregue as configurações:
   ```sh
   source ~/.bashrc   # ou source ~/.zshrc
   ```

### Windows

1. Crie um arquivo chamado `translator.bat` no diretório raiz do seu projeto (ou em um diretório já presente no PATH do sistema) com o conteúdo abaixo. Lembre-se de substituir `C:\caminho\para\seu\projeto` pelo caminho real:
   ```bat
   @echo off
   dart C:\caminho\para\seu\projeto\bin\translator.dart %*
   ```
2. Se o diretório onde o `translator.bat` foi criado não estiver no PATH, adicione-o:
   ```bat
   setx PATH "%PATH%;C:\caminho\para\seu\projeto"
   ```
3. Reinicie o terminal para que as alterações tenham efeito.

## Execução do App

Após concluir as configurações, abra um terminal e execute:
```sh
translator --help
```
O comando deverá exibir as opções disponíveis do app, confirmando que tudo foi configurado corretamente.