import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

abstract class Translator {
  Future<String> translate(String text,
      {required Function onFirstModelError, bool useSecond = false});
}

class TranslatorImp implements Translator {
  final List<String> _models = [
    // 'gemini-2.0-flash-thinking-exp-1219',
    // 'gemini-1.5-flash',
    // 'gemini-exp-1206',
    'gemini-2.5-flash-lite-preview-06-17', // good for translate
    'gemini-2.5-pro',
    'gemini-2.5-flash',
    'gemma-3-27b-it',
    'gemini-2.0-flash',
  ];

  /// Função de tradução que aceita texto e retorna o texto traduzido
  @override
  Future<String> translate(String text,
      {required Function onFirstModelError, bool useSecond = false}) async {
    ensureAPIKeyExists();

    try {
      return await getResponse(_models.first, text);
    } catch (e) {
      if (useSecond) rethrow;
      print('🍀 Erro com ${_models.first}, tentando novamente em 40s🚫');
      print('🚫🚫 $e 🚫🚫');
      onFirstModelError();
      await Future.delayed(const Duration(seconds: 40));
      return await getResponse(_models.first, text);
    }
  }

  Future<String> getResponse(String modelType, String text) async {
    final model = getModel(modelType);

    final chat = model.startChat(history: [
      Content('user', [
        TextPart(
            '[`AboutDialog`]: {{site.api}}/flutter/material/AboutDialog-class.html\n[Adding Assets and Images in Flutter]: /ui/assets/assets-and-images\n[`AlertDialog`]: {{site.api}}/flutter/material/AlertDialog-class.html'),
      ]),
      Content('model', [
        TextPart(
            '[`AboutDialog`]: {{site.api}}/flutter/material/AboutDialog-class.html\n[Adicionando Assets e Imagens no Flutter]: /ui/assets/assets-and-images\n[`AlertDialog`]: {{site.api}}/flutter/material/AlertDialog-class.html'),
      ]),
      Content('user', [
        TextPart('dont translate thoses links\n'),
      ]),
      Content('model', [
        TextPart(
            '[`AboutDialog`]: {{site.api}}/flutter/material/AboutDialog-class.html\n[Adding Assets and Images in Flutter]: /ui/assets/assets-and-images\n[`AlertDialog`]: {{site.api}}/flutter/material/AlertDialog-class.html'),
      ]),
      Content('user', [
        TextPart(
            'em arquivo grandes viram assim, evite.\n\noutput from large contet:\n[25648](https://github.com/flutter/engine/pull/25548) [macos] Libera o buffer de pixel copiado após a criação da textura (cla: sim, aguardando tree verde, platform-macos, embedder, cp: 2.2)\n\n[25649](https://github.### aguardando a árvore ficar verde - 1309 pull requests'),
      ]),
      Content('model', [
        TextPart(
            'evite assim:\n(https://github.com/flutter/engine/pull/25548) [macos] Libera o buffer de pixel copiado após a criação da textura (cla: sim, aguardando tree verde, platform-macos, embedder, cp: 2.2)\n\n(https://github.com/flutter/engine/pull/25548) [macos] Libera o buffer de pixel copiado após a criação da textura (cla: sim, aguardando tree verde, platform-macos, embedder, cp: 2.2)'),
      ]),
      Content('user', [
        TextPart(
            'Algumas vezes vocês está esquecendo de devolver header com ### traduzido, ele simplemente não está na resposta.\n'),
      ]),
      Content('model', [
        TextPart(
            'Entendido. Vou me atentar para garantir que os cabeçalhos marcados com `###` sejam traduzidos e incluídos corretamente nas respostas futuras, mantendo a formatação original.'),
      ]),
      Content('user', [
        TextPart(
            'Utilizamos link por ref e ao traduzir links, não traduzir a ref\n\n[`pubspec.yaml` file][`pubspec.yaml` file] or [Adding assets and images][Adding assets and images].\n\n# não deve ser traduzido\n[Adding assets and images]: /ui/assets/assets-and-images'),
      ]),
      Content('model', [
        TextPart(
            '[`pubspec.yaml` file][`pubspec.yaml` file] ou [Adicionando assets e imagens][Adding assets and images].\n\n# não deve ser traduzido\n[Adding assets and images]: /ui/assets/assets-and-images'),
      ]),
      Content('user', [
        TextPart(
            'E também para links-ref quebrado. Mantenha o traduzido\n\nThe [Material library][Material library] implements widgets that follow [Material\nDesign][Material\nDesign] principles.\n\n[Material Design]: {{site.material}}/styles\n'),
      ]),
      Content('model', [
        TextPart(
            'O [Material library][Material library] implementa widgets que seguem os princípios do [Material Design][Material Design].\n\n[Material Design]: {{site.material}}/styles'),
      ]),
      Content('user', [
        TextPart(
            'Você está traduzindo os link ref no texto e quando vou fazer a verificação automática dos links, quebra. Por favor, não traduza.'),
      ]),
      Content('model', [
        TextPart(
            'Compreendido. A partir de agora, não traduzirei os textos de exibição (anchors) dos links de referência interna, como `[Material library]` ou `[Material Design]`, quando eles apontam para informações dentro do mesmo documento ou para referências específicas. Manterei o texto original para garantir a integridade das referências internas e evitar quebras na verificação automática de links.'),
      ]),
      Content('user', [
        TextPart(
            'Eu tive esse erro do meu sistema de verificar referencia\nLink issue: Broken references (no definition found): debugging layout issues visually, layout widgets, visible widget, text, images, icons, apple\'s human interface guidelines for ios, common layout widgets, file, pavlova image, pubspec file, material 2 design palette'),
      ]),
      Content('model', [
        TextPart(
            'Entendido. Para resolver esse problema e garantir que as referências sejam verificadas corretamente, irei **manter os textos de exibição (anchors) dos links internos exatamente como estão no original**, sem tradução. Isso inclui referências a `debugging layout issues visually`, `layout widgets`, `visible widget`, `text`, `images`, `icons`, `apple\'s human interface guidelines for ios`, `common layout widgets`, `file`, `pavlova image`, `pubspec file` e `material 2 design palette`.\n\nA seguir, apresento a correção com base na sua solicitação:\n\ndebugging layout issues visually, layout widgets, visible widget, text, images, icons, apple\'s human interface guidelines for ios, common layout widgets, file, pavlova image, pubspec file, material 2 design palette.'),
      ]),
    ]);

    final content = Content.text(text);

    final response = await chat.sendMessage(content);

    // Retorna o texto traduzido
    return response.text ?? '';
  }

  GenerativeModel getModel(String model) {
    final apiKey = Platform.environment['GEMINI_API_KEY']!;
    return GenerativeModel(
      model: model,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 1,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 8192,
        responseMimeType: 'text/plain',
      ),
      systemInstruction: Content.system(
          '''Traduza o seguinte texto técnico sobre desenvolvimento de aplicativos Flutter do inglês para o português brasileiro, mantendo a formatação, as quebras de linha originais e os recuos do documento. Identifique-os e trate cada tipo de formatação como cada um exige (HTML, YAML, Markdown, etc). Preserve a terminologia técnica no idioma original sempre que necessário para garantir clareza e precisão, especialmente termos como 'widget', 'bundle', 'asset', 'design patterns', 'SUT', 'flag' e outros termos técnicos específicos. Não traduza esses termos para o inglês. Certifique-se de que o texto traduzido seja fluido, claro e adequado para desenvolvedores brasileiros. Caso o texto contenha links ou referências ancoradas, traduza os textos de exibição (anchors) para o português somente quando necessário para manter a coerência do conteúdo, mas mantenha as URLs intactas no formato original. Não altere a estrutura ou os elementos específicos do documento, como cabeçalhos, listas e imagens.

O importante é manter o número de linhas equivalentes ao original, preservando a formatação do texto e os recuos.  O limite de largura dos blocos de texto deve ser ajustado para que a saída tenha a mesma quantidade de linhas do bloco de texto original.  Blocos de texto geralmente estão separados por quebras de linha vazias; mantenha essas linhas vazias.

Observe a quatidade de quebras de linhas para manter igual o original. Isso implica em deixar linhas curtas muitas vezse entre 50 e 120 chars, porém se atente soment ao número de linhas do bloco em tradução

Mantenha o contexto técnico preciso e a formatação original, evitando traduções literais que soem estranhas ou pouco naturais no português brasileiro, priorizando a fluidez e clareza.  Traduza termos técnicos apenas se houver equivalentes amplamente reconhecidos no Brasil, e forneça a primeira tradução entre parênteses para guiar o leitor. Omita termos como 'underlying' e semelhantes que são específicos do inglês e que podem ser omitidos em português sem alterar o sentido original.

Links devem ser mantidos funcionais e ancorados corretamente. Não traduza as referências dos links que ficam no rodapé ou logo após a seção adjacente.

Traduza os cabeçalhos e títulos para o português, mantendo a estrutura original do documento. Certifique-se de que os títulos sejam claros e representem adequadamente o conteúdo subsequente.

Preste atenção a expressões idiomáticas que não possuem tradução direta; adapte o significado para se alinhar ao contexto brasileiro. Exemplos, como trechos de código e formatações de console, devem permanecer idênticos para evitar confusões no uso técnico. No caso de instruções, como comandos no terminal, mantenha o texto em inglês para não interferir no funcionamento, mas explique em português quando necessário.
'''),
    );
  }

  void ensureAPIKeyExists() {
    final apiKey = Platform.environment['GEMINI_API_KEY'];
    if (apiKey == null) {
      stderr.writeln(r'No $GEMINI_API_KEY environment variable');
      exit(1);
    }
  }
}
