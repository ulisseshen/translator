---
ia-translate: true
title: Visão geral da arquitetura do Flutter
description: >
  Uma visão geral de alto nível da arquitetura do Flutter,
  incluindo os princípios e conceitos centrais que formam seu design.
---

<?code-excerpt path-base="resources/architectural_overview/"?>

Este artigo tem como objetivo fornecer uma visão geral de alto nível da arquitetura do
Flutter, incluindo os princípios e conceitos centrais que formam seu design.
Se você estiver interessado em como arquitetar um aplicativo Flutter,
confira [Architecting Flutter apps][Architecting Flutter apps].

[Architecting Flutter apps]: /app-architecture

Flutter é um toolkit de UI multiplataforma projetado para permitir a reutilização de código
entre sistemas operacionais como iOS, Android, web e desktop,
permitindo também que os
aplicativos interajam diretamente com os serviços subjacentes da plataforma.
O objetivo é permitir que os desenvolvedores entreguem aplicativos de alto desempenho
que se sintam naturais em diferentes plataformas,
abraçando as diferenças onde elas existem, enquanto compartilham o máximo de
código possível.

Durante o desenvolvimento, os aplicativos Flutter são executados em uma VM que oferece
hot reload de estado para alterações sem a necessidade de uma recompilação completa.
(Na web, o Flutter suporta hot restart e
[hot reload por meio de um flag][hot reload behind a flag].)
Para lançamento, os aplicativos Flutter são compilados diretamente para código de máquina,
sejam instruções Intel x64 ou ARM,
ou para JavaScript se o destino for a web.
O framework é de código aberto, com uma licença BSD permissiva,
e possui um ecossistema vibrante de pacotes de terceiros que
complementam a funcionalidade da biblioteca principal.

[hot reload behind a flag]: /platform-integration/web/building#hot-reload-web

Esta visão geral é dividida em várias seções:

1. O **modelo de camadas**: As peças das quais o Flutter é construído.
1. **Interfaces de usuário reativas**: Um conceito central para o desenvolvimento de interfaces de usuário no Flutter.
1. Uma introdução aos **widgets**: Os blocos de construção fundamentais
   das interfaces de usuário do Flutter.
1. O **processo de renderização**: Como o Flutter transforma código de UI em pixels.
1. Uma visão geral dos **embedders de plataforma**: O código que permite que sistemas operacionais móveis e de desktop executem aplicativos Flutter.
1. **Integrando o Flutter com outro código**: Informações sobre
   diferentes técnicas disponíveis para aplicativos Flutter.
1. **Suporte para a web**: Considerações finais sobre as características do Flutter em um ambiente de navegador.

## Camadas arquiteturais

O Flutter é projetado como um sistema extensível e em camadas. Ele existe como uma série de
bibliotecas independentes que dependem da camada subjacente. Nenhuma camada tem acesso privilegiado à camada abaixo, e cada parte do nível do framework é
projetada para ser opcional e substituível.

{% comment %}
Os diagramas PNG neste documento foram criados usando draw.io. Os metadados do draw.io
estão incorporados no próprio arquivo PNG, portanto, você pode abrir o PNG diretamente
do draw.io para editar os componentes individuais.

As seguintes configurações foram usadas:

 - Selecionar tudo (para evitar exportar a própria tela)
 - Exportar como PNG, zoom 300% (para uma saída de tamanho razoável)
 - Habilitar _Fundo Transparente_
 - Habilitar _Apenas Seleção_, _Cortar_
 - Habilitar _Incluir uma cópia do meu diagrama_
{% endcomment %}

![Diagrama
arquitetural](/assets/images/docs/arch-overview/archdiagram.png){:width="100%"}

Para o sistema operacional subjacente, os aplicativos Flutter são empacotados da
mesma forma que qualquer outro aplicativo nativo. Um embedder específico da plataforma fornece
um ponto de entrada; coordena-se com o sistema operacional subjacente para acesso a
serviços como superfícies de renderização, acessibilidade e entrada; e gerencia o
loop de eventos de mensagens. O embedder é escrito em uma linguagem apropriada
para a plataforma: atualmente Java e C++ para Android, Swift e
Objective-C/Objective-C++ para iOS e macOS,
e C++ para Windows e Linux. Usando o embedder, o código Flutter
pode ser integrado a um aplicativo existente como um módulo,
ou o código pode ser o conteúdo inteiro do aplicativo.
O Flutter inclui vários embedders
para plataformas de destino comuns, mas [outros embedders também
existem](https://hover.build/blog/one-year-in/).

No núcleo do Flutter está o **Flutter engine**,
que é majoritariamente escrito em C++ e suporta
as primitivas necessárias para suportar todos os aplicativos Flutter.
O engine é responsável por rasterizar cenas compostas
sempre que um novo quadro precisa ser pintado.
Ele fornece a implementação de baixo nível da API principal do Flutter,
incluindo gráficos (por meio do [Impeller][Impeller]
no iOS, Android e desktop (por meio de um flag),
e [Skia][Skia] em outras plataformas), layout de texto,
I/O de arquivos e rede, suporte de acessibilidade,
arquitetura de plugins e um runtime Dart
e cadeia de ferramentas de compilação.

:::note
Se você tiver uma pergunta sobre quais dispositivos suportam
Impeller, confira [Can I use Impeller?][Can I use Impeller?]
para informações detalhadas.
:::

[Can I use Impeller?]: {{site.main-url}}/go/can-i-use-impeller
[Skia]: https://skia.org
[Impeller]: /perf/impeller

O engine é exposto ao framework Flutter por meio do
[`dart:ui`]({{site.repo.flutter}}/tree/main/engine/src/flutter/lib/ui),
que envolve o código C++ subjacente em classes Dart. Esta biblioteca
expõe as primitivas de mais baixo nível, como classes para controle de entrada,
substituindo gráficos e texto.

Tipicamente, os desenvolvedores interagem com o Flutter por meio do **Flutter framework**,
que fornece um framework moderno e reativo escrito na linguagem Dart. Ele
inclui um rico conjunto de bibliotecas de plataforma, layout e fundamentais, composto de
uma série de camadas. Trabalhando de baixo para cima, temos:

* Classes **[foundational]({{site.api}}/flutter/foundation/foundation-library.html)**
  básicas, e serviços de bloco de construção como
  **[animation]({{site.api}}/flutter/animation/animation-library.html),
  [painting]({{site.api}}/flutter/painting/painting-library.html) e
  [gestures]({{site.api}}/flutter/gestures/gestures-library.html)** que oferecem
  abstrações comumente usadas sobre os fundamentos subjacentes.
* A **[camada de renderização]({{site.api}}/flutter/rendering/rendering-library.html)** fornece uma
  abstração para lidar com o layout. Com esta camada, você pode construir uma árvore
  de objetos renderizáveis. Você pode manipular esses objetos dinamicamente, com a
  árvore atualizando automaticamente o layout para refletir suas mudanças.
* A **[camada de widgets]({{site.api}}/flutter/widgets/widgets-library.html)** é
  uma abstração de composição. Cada objeto de renderização na camada de renderização tem uma
  classe correspondente na camada de widgets. Além disso, a camada de widgets
  permite definir combinações de classes que você pode reutilizar. Esta é a
  camada na qual o modelo de programação reativa é introduzido.
* As bibliotecas
  **[Material]({{site.api}}/flutter/material/material-library.html)**
  e
  **[Cupertino]({{site.api}}/flutter/cupertino/cupertino-library.html)**
  oferecem conjuntos abrangentes de controles que usam as primitivas de composição da camada de widgets para implementar as linguagens de design Material ou iOS.

O framework Flutter é relativamente pequeno; muitos recursos de nível superior que
os desenvolvedores podem usar são implementados como pacotes, incluindo plugins de plataforma como [camera]({{site.pub}}/packages/camera) e
[webview]({{site.pub}}/packages/webview_flutter), bem como recursos agnósticos de plataforma
como [characters]({{site.pub}}/packages/characters),
[http]({{site.pub}}/packages/http) e
[animations]({{site.pub}}/packages/animations) que se baseiam nas bibliotecas principais Dart e
Flutter. Alguns desses pacotes vêm do ecossistema mais amplo,
cobrindo serviços como [pagamentos no aplicativo]({{site.pub}}/packages/square_in_app_payments), [autenticação da Apple]({{site.pub}}/packages/sign_in_with_apple) e
[animações]({{site.pub}}/packages/lottie).

O restante desta visão geral navega amplamente pelas camadas, começando com o
paradigma reativo de desenvolvimento de UI. Em seguida, descrevemos como os widgets são compostos
juntos e convertidos em objetos que podem ser renderizados como parte de um
aplicativo. Descrevemos como o Flutter interopera com outro código em um nível de plataforma,
antes de dar um breve resumo de como o suporte do Flutter para web difere de outros
destinos.

## Anatomia de um app

O diagrama a seguir oferece uma visão geral das peças
que compõem um aplicativo Flutter regular gerado por `flutter create`.
Ele mostra onde o Flutter Engine se encaixa nesta pilha,
destaca os limites da API e identifica os repositórios
onde as peças individuais residem. A legenda abaixo esclarece
alguma terminologia comumente usada para descrever as
peças de um aplicativo Flutter.

<img src='/assets/images/docs/app-anatomy.svg' alt='As camadas de um app Flutter criado por "flutter create": Dart app, framework, engine, embedder, runner'>

**Dart App**
* Compõe widgets na UI desejada.
* Implementa lógica de negócios.
* Pertence ao desenvolvedor do app.

**Framework** ([código fonte]({{site.repo.flutter}}/tree/main/packages/flutter/lib))
* Fornece API de nível superior para construir aplicativos de alta qualidade
  (por exemplo, widgets, hit-testing, detecção de gestos,
  acessibilidade, entrada de texto).
* Compõe a árvore de widgets do app em uma cena.

**Engine** ([código fonte]({{site.repo.flutter}}/tree/main/engine/src/flutter/shell/common))
* Responsável por rasterizar cenas compostas.
* Fornece implementação de baixo nível das APIs principais do Flutter
  (por exemplo, gráficos, layout de texto, runtime Dart).
* Expõe sua funcionalidade ao framework usando a **API dart:ui**.
* Integra-se a uma plataforma específica usando a **Embedder API** do Engine.

**Embedder** ([código fonte]({{site.repo.flutter}}/tree/main/engine/src/flutter/shell/platform))
* Coordena com o sistema operacional subjacente
  para acesso a serviços como superfícies de renderização,
  acessibilidade e entrada.
* Gerencia o loop de eventos.
* Expõe a **API específica da plataforma** para integrar o Embedder aos apps.

**Runner**
* Compõe as peças expostas pela API específica da plataforma
  do Embedder em um pacote de aplicativo executável na plataforma de destino.
* Parte do template do app gerado por `flutter create`,
  pertence ao desenvolvedor do app.

## Interfaces de usuário reativas

À primeira vista, o Flutter é [um framework de UI reativo e declarativo][faq],
no qual o desenvolvedor fornece um mapeamento do estado da aplicação para o estado da interface,
e o framework assume a tarefa de atualizar a interface em tempo de execução
quando o estado da aplicação muda. Este modelo é inspirado pelo
[trabalho que veio do Facebook para o seu próprio framework React][fb],
que inclui um repensar de muitos princípios de design tradicionais.

[faq]: /resources/faq#what-programming-paradigm-does-flutters-framework-use
[fb]: {{site.yt.watch}}?time_continue=2&v=x7cQ3mrcKaY&feature=emb_logo

Na maioria dos frameworks de UI tradicionais, o estado inicial da interface do usuário é
descrito uma vez e depois atualizado separadamente pelo código do usuário em tempo de execução, em resposta a eventos. Um desafio dessa abordagem é que, à medida que o aplicativo cresce em complexidade,
o desenvolvedor precisa estar ciente de como as mudanças de estado se propagam
por toda a UI. Por exemplo, considere a seguinte UI:

![Dialog de seletor de cores](/assets/images/docs/arch-overview/color-picker.png){:width="66%"}

Existem muitos lugares onde o estado pode ser alterado: a caixa de cor, o slider de matiz, os botões de rádio. À medida que o usuário interage com a UI, as mudanças devem ser refletidas em todos os outros lugares. Pior ainda, a menos que se tome cuidado, uma pequena mudança em uma parte da interface do usuário pode causar efeitos em cascata para peças de código aparentemente não relacionadas.

Uma solução para isso é uma abordagem como MVC, onde você envia as mudanças de dados para o modelo através do controller, e então o modelo envia o novo estado para a view através do controller. No entanto, isso também é problemático, pois a criação e atualização de elementos de UI são duas etapas separadas que podem facilmente sair de sincronia.

O Flutter, juntamente com outros frameworks reativos, adota uma abordagem alternativa para este problema,
desacoplando explicitamente a interface do usuário de seu estado subjacente. Com APIs no estilo React, você apenas cria a descrição da interface, e o framework se encarrega de usar essa única configuração para criar e/ou atualizar a interface do usuário conforme apropriado.

No Flutter, os widgets (semelhantes aos componentes no React) são representados por classes imutáveis que são usadas para configurar uma árvore de objetos. Esses widgets são usados para gerenciar uma árvore separada de objetos para layout, que é então usada para gerenciar uma árvore separada de objetos para composição. O Flutter é, em sua essência, uma série de mecanismos para percorrer eficientemente as partes modificadas das árvores, converter árvores de objetos em árvores de objetos de nível inferior e propagar mudanças por essas árvores.

Um widget declara sua interface de usuário substituindo o método `build()`, que é uma função que converte estado em UI:

```plaintext
UI = f(state)
```

O método `build()` é projetado para ser rápido de executar e deve ser livre de efeitos colaterais, permitindo que ele seja chamado pelo framework sempre que necessário (potencialmente com a mesma frequência de cada quadro renderizado).

Essa abordagem depende de certas características de um runtime de linguagem (em particular, instanciação e exclusão rápida de objetos). Felizmente, [Dart é particularmente adequado para esta tarefa]({{site.flutter-medium}}/flutter-dont-fear-the-garbage-collector-d69b3ff1ca30).

## Widgets

Como mencionado, o Flutter enfatiza os widgets como uma unidade de composição. Widgets são os blocos de construção da interface de usuário de um aplicativo Flutter, e cada widget é uma declaração imutável de parte da interface do usuário.

Os widgets formam uma hierarquia baseada em composição. Cada widget se aninha dentro de seu pai e pode receber contexto do pai. Essa estrutura se estende até o widget raiz (o contêiner que hospeda o aplicativo Flutter, tipicamente `MaterialApp` ou `CupertinoApp`), como este exemplo trivial mostra:

<?code-excerpt "lib/main.dart (main)"?>
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('My Home Page')),
        body: Center(
          child: Builder(
            builder: (context) {
              return Column(
                children: [
                  const Text('Hello World'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      print('Click!');
                    },
                    child: const Text('A button'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
```

No código anterior, todas as classes instanciadas são widgets.

Os aplicativos atualizam sua interface de usuário em resposta a eventos (como uma interação do usuário) informando ao framework para substituir um widget na hierarquia por outro widget. O framework então compara os novos e antigos widgets e atualiza eficientemente a interface do usuário.

O Flutter tem suas próprias implementações de cada controle de UI, em vez de se deferir aos fornecidos pelo sistema: por exemplo, existe uma implementação pura [Dart]({{site.api}}/flutter/cupertino/CupertinoSwitch-class.html) tanto do [controle Toggle do iOS]({{site.apple-dev}}/design/human-interface-guidelines/toggles) quanto do [para]({{site.api}}/flutter/material/Switch-class.html) o [equivalente do Android]({{site.material}}/components/switch).

Essa abordagem oferece vários benefícios:

* Proporciona extensibilidade ilimitada. Um desenvolvedor que deseja uma variante do controle Switch pode criar uma de qualquer forma arbitrária e não está limitado aos pontos de extensão fornecidos pelo sistema operacional.
* Evita um gargalo de desempenho significativo, permitindo que o Flutter componha toda a cena de uma vez, sem transições entre o código Flutter e o código da plataforma.
* Desacopla o comportamento do aplicativo de quaisquer dependências do sistema operacional. O aplicativo se parece e se sente da mesma forma em todas as versões do sistema operacional, mesmo que o sistema operacional tenha alterado as implementações de seus controles.

### Composição

Os widgets são tipicamente compostos por muitos outros widgets pequenos e de propósito único que se combinam para produzir efeitos poderosos.

Onde possível, o número de conceitos de design é mantido ao mínimo, permitindo que o vocabulário total seja grande. Por exemplo, na camada de widgets, o Flutter usa o mesmo conceito central (um `Widget`) para representar o desenho na tela, o layout (posicionamento e dimensionamento), a interatividade do usuário, o gerenciamento de estado, a tematização, animações e navegação. Na camada de animação, um par de conceitos, `Animation`s e `Tween`s, cobrem a maior parte do espaço de design. Na camada de renderização, `RenderObject`s são usados para descrever layout, pintura, hit testing e acessibilidade. Em cada um desses casos, o vocabulário correspondente acaba sendo grande: existem centenas de widgets e render objects, e dezenas de tipos de animação e tween.

A hierarquia de classes é deliberadamente rasa e ampla para maximizar o número possível de combinações, focando em widgets pequenos e composíveis que cada um faz uma coisa bem. Recursos centrais são abstratos, com até mesmo recursos básicos como padding e alinhamento sendo implementados como componentes separados, em vez de serem embutidos no núcleo. (Isso também contrasta com APIs mais tradicionais onde recursos como padding são embutidos no núcleo comum de cada componente de layout.) Assim, por exemplo, para centralizar um widget, em vez de ajustar uma propriedade `Align` teórica, você o envolve em um widget [`Center`]({{site.api}}/flutter/widgets/Center-class.html).

Existem widgets para padding, alinhamento, linhas, colunas e grades. Esses widgets de layout não têm uma representação visual própria. Em vez disso, seu único propósito é controlar algum aspecto do layout de outro widget. O Flutter também inclui widgets utilitários que aproveitam essa abordagem de composição.

Por exemplo, [`Container`]({{site.api}}/flutter/widgets/Container-class.html), um widget comumente usado, é composto por vários widgets responsáveis por layout, pintura, posicionamento e dimensionamento. Especificamente, o `Container` é composto pelos widgets [`LimitedBox`]({{site.api}}/flutter/widgets/LimitedBox-class.html), [`ConstrainedBox`]({{site.api}}/flutter/widgets/ConstrainedBox-class.html), [`Align`]({{site.api}}/flutter/widgets/Align-class.html), [`Padding`]({{site.api}}/flutter/widgets/Padding-class.html), [`DecoratedBox`]({{site.api}}/flutter/widgets/DecoratedBox-class.html) e [`Transform`]({{site.api}}/flutter/widgets/Transform-class.html), como você pode ver lendo seu código fonte. Uma característica definidora do Flutter é que você pode investigar o código fonte de qualquer widget e examiná-lo. Assim, em vez de subclassificar `Container` para produzir um efeito personalizado, você pode compô-lo e outros widgets de maneiras novas, ou simplesmente criar um novo widget usando `Container` como inspiração.

### Construindo widgets

Conforme mencionado anteriormente, você determina a representação visual de um widget substituindo a função
[`build()`]({{site.api}}/flutter/widgets/StatelessWidget/build.html) para retornar uma nova árvore de elementos. Essa árvore representa a parte da interface do usuário do widget em termos mais concretos. Por exemplo, um widget de barra de ferramentas pode ter uma função de build que retorna um [layout horizontal]({{site.api}}/flutter/widgets/Row-class.html) de algum [texto]({{site.api}}/flutter/widgets/Text-class.html) e [vários]({{site.api}}/flutter/material/IconButton-class.html) [botões]({{site.api}}/flutter/material/PopupMenuButton-class.html). Conforme necessário, o framework solicita recursivamente que cada widget seja construído até que a árvore seja inteiramente descrita por [objetos concretos renderizáveis]({{site.api}}/flutter/widgets/RenderObjectWidget-class.html). O framework, em seguida, une os objetos renderizáveis em uma árvore de objetos renderizáveis.

A função de build de um widget deve ser livre de efeitos colaterais. Sempre que a função é solicitada a construir, o widget deve retornar uma nova árvore de widgets[^1], independentemente do que o widget retornou anteriormente. O framework realiza o trabalho pesado de determinar quais métodos de build precisam ser chamados com base na árvore de objetos de renderização (descrito com mais detalhes posteriormente). Mais informações sobre esse processo podem ser encontradas no tópico [Inside Flutter](/resources/inside-flutter#linear-reconciliation).

Em cada frame renderizado, o Flutter pode recriar apenas as partes da UI onde o estado mudou, chamando o método `build()` desse widget. Portanto, é importante que os métodos de build retornem rapidamente, e que trabalhos computacionais pesados sejam feitos de forma assíncrona e armazenados como parte do estado para serem usados por um método de build.

Embora relativamente ingênua na abordagem, essa comparação automatizada é bastante eficaz, permitindo aplicativos interativos de alto desempenho. E o design da função de build simplifica seu código ao focar em declarar do que um widget é feito, em vez das complexidades de atualizar a interface do usuário de um estado para outro.

### Estado do widget

O framework introduz duas classes principais de widget: widgets _com estado_ (stateful) e _sem estado_ (stateless).

Muitos widgets não têm estado mutável: eles não possuem propriedades que mudam com o tempo (por exemplo, um ícone ou um rótulo). Esses widgets herdam de [`StatelessWidget`]({{site.api}}/flutter/widgets/StatelessWidget-class.html).

No entanto, se as características únicas de um widget precisam mudar com base na interação do usuário ou em outros fatores, esse widget é _com estado_. Por exemplo, se um widget tem um contador que incrementa sempre que o usuário toca em um botão, o valor do contador é o estado desse widget. Quando esse valor muda, o widget precisa ser reconstruído para atualizar sua parte da UI. Esses widgets herdam de [`StatefulWidget`]({{site.api}}/flutter/widgets/StatefulWidget-class.html) e (como o próprio widget é imutável) eles armazenam o estado mutável em uma classe separada que herda de [`State`]({{site.api}}/flutter/widgets/State-class.html). `StatefulWidget`s não possuem um método de build; em vez disso, sua interface do usuário é construída através de seu objeto `State`.

Sempre que você muta um objeto `State` (por exemplo, incrementando o contador), você deve chamar [`setState()`]({{site.api}}/flutter/widgets/State/setState.html) para sinalizar ao framework para atualizar a interface do usuário chamando novamente o método de build do `State`.

Ter objetos de estado e widget separados permite que outros widgets tratem widgets sem estado e com estado da mesma forma, sem se preocupar em perder estado. Em vez de precisar manter um filho para preservar seu estado, o pai pode criar uma nova instância do filho a qualquer momento sem perder o estado persistente do filho. O framework faz todo o trabalho de encontrar e reutilizar objetos de estado existentes quando apropriado.

### Gerenciamento de estado

Portanto, se muitos widgets podem conter estado, como o estado é gerenciado e passado pelo sistema?

Como qualquer outra classe, você pode usar um construtor em um widget para inicializar seus dados, de modo que um método `build()` possa garantir que qualquer widget filho seja instanciado com os dados necessários:

```dart
@override
Widget build(BuildContext context) {
   return ContentWidget([!importantState!]);
}
```

Onde `importantState` é um placeholder para a classe que contém o estado importante para o `Widget`.

À medida que as árvores de widgets ficam mais profundas, no entanto, passar informações de estado para cima e para baixo na hierarquia da árvore se torna complicado. Assim, um terceiro tipo de widget, [`InheritedWidget`][`InheritedWidget`], fornece uma maneira fácil de obter dados de um ancestral compartilhado. Você pode usar `InheritedWidget` para criar um widget de estado que envolve um ancestral comum na árvore de widgets, como mostrado neste exemplo:

![Inherited widgets](/assets/images/docs/arch-overview/inherited-widget.png){:width="50%" .diagram-wrap}

[`InheritedWidget`]: {{site.api}}/flutter/widgets/InheritedWidget-class.html

Sempre que um dos objetos `ExamWidget` ou `GradeWidget` precisa de dados do `StudentState`, ele pode acessá-lo com um comando como:

```dart
final studentState = StudentState.of(context);
```

A chamada `of(context)` pega o contexto de build (um identificador para a localização atual do widget na árvore) e retorna [o ancestral mais próximo na árvore][the nearest ancestor in the tree] que corresponde ao tipo `StudentState`. `InheritedWidget`s também oferecem um método `updateShouldNotify()`, que o Flutter chama para determinar se uma mudança de estado deve acionar a reconstrução dos widgets filhos que o utilizam.

[the nearest ancestor in the tree]: {{site.api}}/flutter/widgets/BuildContext/dependOnInheritedWidgetOfExactType.html

O próprio Flutter usa `InheritedWidget` extensivamente como parte do framework para estado compartilhado, como o _tema visual_ da aplicação, que inclui [propriedades como cor e estilos de texto][properties like color and type styles] que são onipresentes em uma aplicação. O método `build()` do `MaterialApp` insere um tema na árvore ao construir, e então mais abaixo na hierarquia um widget pode usar o método `.of()` para procurar os dados de tema relevantes.

Por exemplo:

<?code-excerpt "lib/main.dart (container)"?>
```dart
Container(
  color: Theme.of(context).secondaryHeaderColor,
  child: Text(
    'Text with a background color',
    style: Theme.of(context).textTheme.titleLarge,
  ),
);
```

[properties like color and type styles]: {{site.api}}/flutter/material/ThemeData-class.html

À medida que as aplicações crescem, abordagens mais avançadas de gerenciamento de estado que reduzem a cerimônia de criação e uso de widgets com estado se tornam mais atraentes. Muitos aplicativos Flutter usam pacotes utilitários como
[provider]({{site.pub}}/packages/provider), que fornece um wrapper em torno de `InheritedWidget`. A arquitetura em camadas do Flutter também permite abordagens alternativas para implementar a transformação de estado em UI, como o pacote
[flutter_hooks]({{site.pub}}/packages/flutter_hooks).

## Renderização e layout

Esta seção descreve o pipeline de renderização, que é a série de etapas que o Flutter realiza para converter uma hierarquia de widgets nos pixels reais pintados em uma tela.

### Modelo de renderização do Flutter

Você pode estar se perguntando: se o Flutter é um framework multiplataforma, como ele pode oferecer desempenho comparável a frameworks de plataforma única?

É útil começar pensando em como os aplicativos Android tradicionais funcionam. Ao desenhar, você primeiro chama o código Java do framework Android. As bibliotecas do sistema Android fornecem os componentes responsáveis por se desenharem em um objeto `Canvas`, que o Android pode então renderizar com [Skia][Skia], um motor gráfico escrito em C/C++ que chama a CPU ou GPU para completar o desenho no dispositivo.

Frameworks multiplataforma *tipicamente* funcionam criando uma camada de abstração sobre as bibliotecas nativas subjacentes de UI do Android e iOS, tentando suavizar as inconsistências de cada representação de plataforma. O código do aplicativo é frequentemente escrito em uma linguagem interpretada como JavaScript, que por sua vez deve interagir com as bibliotecas do sistema Android baseadas em Java ou iOS baseadas em Objective-C para exibir a UI. Tudo isso adiciona sobrecarga que pode ser significativa, especialmente onde há muita interação entre a UI e a lógica do aplicativo.

Em contraste, o Flutter minimiza essas abstrações, contornando as bibliotecas de widgets de UI do sistema em favor de seu próprio conjunto de widgets. O código Dart que pinta os visuais do Flutter é compilado em código nativo, que usa Impeller para renderização. O Impeller é enviado junto com o aplicativo, permitindo que o desenvolvedor atualize seu aplicativo para se manter atualizado com as últimas melhorias de desempenho, mesmo que o telefone não tenha sido atualizado com uma nova versão do Android. O mesmo vale para o Flutter em outras plataformas nativas, como Windows ou macOS.

:::note
Se você quiser saber quais dispositivos o Impeller suporta, confira [Can I use Impeller?][Can I use Impeller?]. Para mais informações, visite [Impeller rendering engine][Impeller rendering engine]
:::

[Impeller rendering engine]: /perf/impeller

### De entrada do usuário à GPU

O princípio fundamental que o Flutter aplica ao seu pipeline de renderização é que **simples é rápido**. O Flutter tem um pipeline direto para o fluxo de dados para o sistema, como mostrado no seguinte diagrama de sequenciamento:

![Render pipeline sequencing diagram](/assets/images/docs/arch-overview/render-pipeline.png){:width="100%" .diagram-wrap}

Vamos analisar algumas dessas fases com mais detalhes.

### Build: de Widget a Element

Considere este fragmento de código que demonstra uma hierarquia de widgets:

<?code-excerpt "lib/main.dart (widget-hierarchy)"?>
```dart
Container(
  color: Colors.blue,
  child: Row(
    children: [
      Image.network('https://www.example.com/1.png'),
      const Text('A'),
    ],
  ),
);
```

Quando o Flutter precisa renderizar este fragmento, ele chama o método `build()`, que retorna uma subárvore de widgets que renderiza a UI com base no estado atual do aplicativo. Durante este processo, o método `build()` pode introduzir novos widgets, conforme necessário, com base em seu estado. Como exemplo, no fragmento de código anterior, `Container` tem propriedades `color` e `child`. Ao olhar para o [código-fonte]({{site.repo.flutter}}/blob/02efffc134ab4ce4ff50a9ddd86c832efdb80462/packages/flutter/lib/src/widgets/container.dart#L401) para `Container`, você pode ver que se a cor não for nula, ele insere uma `ColoredBox` representando a cor:

```dart
if (color != null)
  current = ColoredBox(color: color!, child: current);
```

Correspondentemente, os widgets `Image` e `Text` podem inserir widgets filhos como `RawImage` e `RichText` durante o processo de build. A hierarquia de widgets resultante pode, portanto, ser mais profunda do que o código representa, como neste caso[^2]:

![Render pipeline sequencing diagram](/assets/images/docs/arch-overview/widgets.png){:width="40%" .diagram-wrap}

Isso explica por que, ao inspecionar a árvore através de uma ferramenta de depuração como o [Flutter inspector](/tools/devtools/inspector), parte do Flutter/Dart DevTools, você pode ver uma estrutura consideravelmente mais profunda do que em seu código original.

Durante a fase de build, o Flutter traduz os widgets expressos em código em uma **árvore de elementos** correspondente, com um elemento para cada widget. Cada elemento representa uma instância específica de um widget em uma determinada localização na hierarquia da árvore. Existem dois tipos básicos de elementos:

- `ComponentElement`, um host para outros elementos.
- `RenderObjectElement`, um elemento que participa das fases de layout ou pintura.

![Render pipeline sequencing diagram](/assets/images/docs/arch-overview/widget-element.png){:width="85%" .diagram-wrap}

`RenderObjectElement`s são um intermediário entre seu análogo de widget e o `RenderObject` subjacente, que veremos mais adiante.

O elemento para qualquer widget pode ser referenciado através de seu `BuildContext`, que é um identificador para a localização de um widget na árvore. Este é o `context` em uma chamada de função como `Theme.of(context)`, e é fornecido ao método `build()` como um parâmetro.

Como os widgets são imutáveis, incluindo a relação pai/filho entre os nós, qualquer alteração na árvore de widgets (como mudar `Text('A')` para `Text('B')` no exemplo anterior) causa o retorno de um novo conjunto de objetos widget. Mas isso não significa que a representação subjacente precise ser reconstruída. A árvore de elementos é persistente de um frame para outro e, portanto, desempenha um papel crítico de desempenho, permitindo que o Flutter aja como se a hierarquia de widgets fosse totalmente descartável, enquanto armazena em cache sua representação subjacente. Ao percorrer apenas os widgets que mudaram, o Flutter pode reconstruir apenas as partes da árvore de elementos que requerem reconfiguração.

### Layout e renderização

Seria uma aplicação rara que desenhasse apenas um único widget. Uma parte importante de qualquer framework de UI é, portanto, a capacidade de organizar eficientemente uma hierarquia de widgets, determinando o tamanho e a posição de cada elemento antes que eles sejam renderizados na tela.

A classe base para cada nó na árvore de renderização é
[`RenderObject`]({{site.api}}/flutter/rendering/RenderObject-class.html), que
define um modelo abstrato para layout e pintura. Isso é extremamente geral: não se
compromete com um número fixo de dimensões ou mesmo com um sistema de coordenadas
Cartesianas (demonstrado por [este exemplo de um sistema de coordenadas
polar]({{site.dartpad}}/?id=596b1d6331e3b9d7b00420085fab3e27)). Cada
`RenderObject` conhece seu pai, mas sabe pouco sobre seus filhos além de como
visitá-los e suas restrições. Isso fornece ao `RenderObject` abstração suficiente
para ser capaz de lidar com uma variedade de casos de uso.

Durante a fase de build, o Flutter cria ou atualiza um objeto que herda de
`RenderObject` para cada `RenderObjectElement` na árvore de elementos.
`RenderObject`s são primitivas:
[`RenderParagraph`]({{site.api}}/flutter/rendering/RenderParagraph-class.html)
renderiza texto,
[`RenderImage`]({{site.api}}/flutter/rendering/RenderImage-class.html) renderiza
uma imagem, e
[`RenderTransform`]({{site.api}}/flutter/rendering/RenderTransform-class.html)
aplica uma transformação antes de pintar seu filho.

![Diferenças entre a hierarquia de widgets e as árvores de elementos e renderização](/assets/images/docs/arch-overview/trees.png){:width="100%" .diagram-wrap}

A maioria dos widgets do Flutter é renderizada por um objeto que herda da
subclasse `RenderBox`, que representa um `RenderObject` de tamanho fixo em um
espaço Cartesiano 2D. `RenderBox` fornece a base de um modelo de restrição de
caixa (_box constraint model_), estabelecendo uma altura e largura mínima e máxima
para cada widget a ser renderizado.

Para realizar o layout, o Flutter percorre a árvore de renderização em uma
travessia de profundidade e **passa as restrições de tamanho** do pai para o
filho. Ao determinar seu tamanho, o filho _deve_ respeitar as restrições dadas a
ele por seu pai. Os filhos respondem **passando um tamanho** para seu objeto pai
dentro das restrições que o pai estabeleceu.

![Restrições descem, tamanhos sobem](/assets/images/docs/arch-overview/constraints-sizes.png){:width="70%" .diagram-wrap}

Ao final dessa única travessia pela árvore, cada objeto tem um tamanho definido
dentro das restrições de seu pai e está pronto para ser pintado chamando o
método
[`paint()`]({{site.api}}/flutter/rendering/RenderObject/paint.html).

O modelo de restrição de caixa é muito poderoso como uma forma de organizar
objetos em tempo _O(n)_:

- Pais podem ditar o tamanho de um objeto filho definindo restrições máximas e
  mínimas para o mesmo valor. Por exemplo, o objeto de renderização mais alto em
  um aplicativo de telefone restringe seu filho ao tamanho da tela. (Filhos podem
  escolher como usar esse espaço. Por exemplo, eles podem simplesmente centralizar
  o que querem renderizar dentro das restrições ditadas.)
- Um pai pode ditar a largura do filho, mas dar ao filho flexibilidade sobre a
  altura (ou ditar a altura, mas oferecer flexibilidade sobre a largura). Um exemplo
  do mundo real é o texto em fluxo, que pode ter que se ajustar a uma restrição
  horizontal, mas variar verticalmente dependendo da quantidade de texto.

Este modelo funciona mesmo quando um objeto filho precisa saber quanto espaço
tem disponível para decidir como renderizar seu conteúdo. Ao usar um widget
[`LayoutBuilder`]({{site.api}}/flutter/widgets/LayoutBuilder-class.html),
o objeto filho pode examinar as restrições passadas e usá-las para
determinar como irá utilizá-las, por exemplo:

<?code-excerpt "lib/main.dart (layout-builder)"?>
```dart
Widget build(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 600) {
        return const OneColumnLayout();
      } else {
        return const TwoColumnLayout();
      }
    },
  );
}
```

Mais informações sobre o sistema de restrição e layout,
juntamente com exemplos funcionais, podem ser encontradas no
tópico [Entendendo restrições](/ui/layout/constraints).

A raiz de todos os `RenderObject`s é o `RenderView`, que representa a saída total
da árvore de renderização. Quando a plataforma exige um novo quadro para ser
renderizado (por exemplo, devido a
[vsync](https://source.android.com/devices/graphics/implement-vsync) ou porque
uma descompressão/upload de textura está completa), uma chamada é feita ao
método `compositeFrame()`, que faz parte do objeto `RenderView` na raiz
da árvore de renderização. Isso cria um `SceneBuilder` para acionar uma atualização
da cena. Quando a cena está completa, o objeto `RenderView` passa a cena
compositora para o método `Window.render()` em `dart:ui`, que passa o controle
para a GPU para renderizá-la.

Mais detalhes sobre os estágios de composição e rasterização do pipeline estão
fora do escopo deste artigo de alto nível, mas mais informações podem ser
encontradas [nesta palestra sobre o pipeline de renderização do
Flutter]({{site.yt.watch}}?v=UUfXWzp0-DU).

## Integração com outras linguagens

Como vimos, em vez de serem traduzidas para os widgets equivalentes do SO,
as interfaces de usuário do Flutter são construídas, organizadas, compostas e
pintadas pelo próprio Flutter. O mecanismo para obter a textura e participar do
ciclo de vida do aplicativo do sistema operacional subjacente inevitavelmente varia
dependendo das preocupações únicas dessa plataforma. O engine é agnóstico à
plataforma, apresentando um
[ABI (Interface Binária de Aplicação)
estável]({{site.repo.flutter}}/blob/main/engine/src/flutter/shell/platform/embedder/embedder.h)
que fornece a um _embedder_ de plataforma uma maneira de configurar e usar o
Flutter.

O embedder de plataforma é o aplicativo nativo do SO que hospeda todo o conteúdo
do Flutter e atua como a cola entre o sistema operacional host e o Flutter.
Quando você inicia um aplicativo Flutter, o embedder fornece o ponto de entrada,
inicializa o engine Flutter, obtém threads para UI e rasterização, e cria uma
textura na qual o Flutter pode escrever. O embedder também é responsável pelo
ciclo de vida do aplicativo, incluindo gestos de entrada (como mouse, teclado,
toque), redimensionamento de janela, gerenciamento de threads e mensagens de
plataforma. O Flutter inclui embedders de plataforma para Android, iOS, Windows,
macOS e Linux; você também pode criar um embedder de plataforma personalizado,
como em [este exemplo funcional]({{site.github}}/chinmaygarde/fluttercast)
que suporta a remotação de sessões Flutter através de um framebuffer estilo VNC ou
[este exemplo funcional para Raspberry Pi]({{site.github}}/ardera/flutter-pi).

Cada plataforma tem seu próprio conjunto de APIs e restrições. Algumas breves
observações específicas da plataforma:

- No iOS e macOS, o Flutter é carregado no embedder como um `UIViewController`
  ou `NSViewController`, respectivamente. O embedder de plataforma cria um
  `FlutterEngine`, que serve como host para a VM Dart e seu runtime Flutter, e um
  `FlutterViewController`, que se anexa ao `FlutterEngine` para passar eventos
  de entrada UIKit ou Cocoa para o Flutter e exibir quadros
  renderizados pelo `FlutterEngine` usando Metal ou OpenGL.
- No Android, o Flutter é, por padrão, carregado no embedder como uma `Activity`.
  A view é controlada por uma
  [`FlutterView`]({{site.api}}/javadoc/io/flutter/embedding/android/FlutterView.html),
  que renderiza o conteúdo do Flutter como uma view ou uma textura, dependendo dos
  requisitos de composição e ordenação de profundidade do conteúdo do Flutter.
- No Windows, o Flutter é hospedado em um aplicativo Win32 tradicional, e o
  conteúdo é renderizado usando
  [ANGLE](https://chromium.googlesource.com/angle/angle/+/master/README.md), uma
  biblioteca que traduz chamadas de API OpenGL para os equivalentes do DirectX 11.

## Integrando com outras linguagens

O Flutter oferece uma variedade de mecanismos de interoperabilidade, seja você
acessando código ou APIs escritas em uma linguagem como Kotlin ou Swift,
chamando uma API nativa baseada em C, incorporando controles nativos em um
aplicativo Flutter ou incorporando Flutter em um aplicativo existente.

### Canais de plataforma

Para aplicativos móveis e de desktop, o Flutter permite que você chame código
personalizado através de um _canal de plataforma_, que é um mecanismo para
comunicação entre seu código Dart e o código específico da plataforma de seu
aplicativo host. Ao criar um canal comum (encapsulando um nome e um codec),
você pode enviar e receber mensagens entre Dart e um componente de plataforma
escrito em uma linguagem como Kotlin ou Swift. Os dados são serializados de um tipo
Dart como `Map` para um formato padrão, e depois desserializados para uma
representação equivalente em Kotlin (como `HashMap`) ou Swift (como `Dictionary`).

![Como os canais de plataforma permitem que o Flutter se comunique com o código host](/assets/images/docs/arch-overview/platform-channels.png){:width="65%" .diagram-wrap}

O exemplo a seguir é um pequeno exemplo de canal de plataforma de uma chamada
Dart para um manipulador de eventos receptor em Kotlin (Android) ou Swift (iOS):

<?code-excerpt "lib/main.dart (method-channel)"?>
```dart
// Lado Dart
const channel = MethodChannel('foo');
final greeting = await channel.invokeMethod('bar', 'world') as String;
print(greeting);
```

```kotlin
// Android (Kotlin)
val channel = MethodChannel(flutterView, "foo")
channel.setMethodCallHandler { call, result ->
  when (call.method) {
    "bar" -> result.success("Hello, ${call.arguments}")
    else -> result.notImplemented()
  }
}
```

```swift
// iOS (Swift)
let channel = FlutterMethodChannel(name: "foo", binaryMessenger: flutterView)
channel.setMethodCallHandler {
  (call: FlutterMethodCall, result: FlutterResult) -> Void in
  switch (call.method) {
    case "bar": result("Hello, \(call.arguments as! String)")
    default: result(FlutterMethodNotImplemented)
  }
}
```

Mais exemplos de uso de canais de plataforma, incluindo exemplos para plataformas
de desktop, podem ser encontrados no repositório
[flutter/packages]({{site.repo.packages}}).
Existem também [milhares de plugins
já disponíveis]({{site.pub}}/flutter) para Flutter que cobrem muitos
cenários comuns, desde Firebase a anúncios até hardware de dispositivos como
câmera e Bluetooth.

### Foreign Function Interface (FFI)

Para APIs baseadas em C, incluindo aquelas que podem ser geradas para código
escrito em linguagens modernas como Rust ou Go, o Dart fornece um mecanismo direto
para vinculação com código nativo usando a biblioteca `dart:ffi`. O modelo
foreign function interface (FFI) pode ser consideravelmente mais rápido que os
canais de plataforma, pois nenhuma serialização é necessária para passar dados.
Em vez disso, o runtime Dart fornece a capacidade de alocar memória no heap que é
suportada por um objeto Dart e fazer chamadas para bibliotecas estática ou
dinamicamente vinculadas. FFI está disponível para todas as plataformas, exceto
web, onde as [bibliotecas de interop JS][JS interop libraries] e
[`package:web`][`package:web`] servem a um propósito semelhante.

Para usar FFI, você cria um `typedef` para cada uma das assinaturas de método Dart
e não gerenciadas, e instrui a VM Dart a mapear entre elas. Como exemplo, aqui
está um fragmento de código para chamar a API tradicional Win32 `MessageBox()`:

<?code-excerpt "lib/ffi.dart" remove="ignore:"?>
```dart
import 'dart:ffi';
import 'package:ffi/ffi.dart'; // contém o método de extensão .toNativeUtf16()

typedef MessageBoxNative =
    Int32 Function(
      IntPtr hWnd,
      Pointer<Utf16> lpText,
      Pointer<Utf16> lpCaption,
      Int32 uType,
    );

typedef MessageBoxDart =
    int Function(
      int hWnd,
      Pointer<Utf16> lpText,
      Pointer<Utf16> lpCaption,
      int uType,
    );

void exampleFfi() {
  final user32 = DynamicLibrary.open('user32.dll');
  final messageBox = user32.lookupFunction<MessageBoxNative, MessageBoxDart>(
    'MessageBoxW',
  );

  final result = messageBox(
    0, // Sem janela proprietária
    'Mensagem de teste'.toNativeUtf16(), // Mensagem
    'Legenda da janela'.toNativeUtf16(), // Título da janela
    0, // Apenas botão OK
  );
}
```

[JS interop libraries]: {{site.dart-site}}/interop/js-interop
[`package:web`]: {{site.pub-pkg}}/web

### Renderizando controles nativos em um aplicativo Flutter

Como o conteúdo do Flutter é desenhado em uma textura e sua árvore de widgets é
totalmente interna, não há espaço para algo como uma view Android existir dentro
do modelo interno do Flutter ou renderizar intercalado com widgets Flutter.
Isso é um problema para desenvolvedores que gostariam de incluir componentes de
plataforma existentes em seus aplicativos Flutter, como um controle de navegador.

O Flutter resolve isso introduzindo widgets de visualização de plataforma
([`AndroidView`]({{site.api}}/flutter/widgets/AndroidView-class.html)
e [`UiKitView`]({{site.api}}/flutter/widgets/UiKitView-class.html))
que permitem incorporar esse tipo de conteúdo em cada plataforma. As
visualizações de plataforma podem ser integradas com outro conteúdo Flutter[^3].
Cada um desses widgets atua como um intermediário para o sistema operacional
subjacente. Por exemplo, no Android, `AndroidView` serve três funções principais:

- Fazendo uma cópia da textura gráfica renderizada pela visualização nativa e
  apresentando-a ao Flutter para composição como parte de uma superfície renderizada
  pelo Flutter a cada quadro pintado.
- Respondendo a testes de acerto e gestos de entrada, e traduzindo-os para a
  entrada nativa equivalente.
- Criando um análogo da árvore de acessibilidade, e passando comandos e respostas
  entre as camadas nativa e Flutter.

Inevitavelmente, há uma certa quantidade de sobrecarga associada a essa
sincronização. Em geral, portanto, essa abordagem é mais adequada para controles
complexos como Google Maps, onde a reimplementação em Flutter não é prática.

Normalmente, um aplicativo Flutter instancia esses widgets em um método `build()`
com base em um teste de plataforma. Como exemplo, do plugin
[google_maps_flutter]({{site.pub}}/packages/google_maps_flutter):

```dart
if (defaultTargetPlatform == TargetPlatform.android) {
  return AndroidView(
    viewType: 'plugins.flutter.io/google_maps',
    onPlatformViewCreated: onPlatformViewCreated,
    gestureRecognizers: gestureRecognizers,
    creationParams: creationParams,
    creationParamsCodec: const StandardMessageCodec(),
  );
} else if (defaultTargetPlatform == TargetPlatform.iOS) {
  return UiKitView(
    viewType: 'plugins.flutter.io/google_maps',
    onPlatformViewCreated: onPlatformViewCreated,
    gestureRecognizers: gestureRecognizers,
    creationParams: creationParams,
    creationParamsCodec: const StandardMessageCodec(),
  );
}
return Text(
    '$defaultTargetPlatform ainda não é suportado pelo plugin de mapas');
```

A comunicação com o código nativo subjacente ao `AndroidView` ou `UiKitView`
geralmente ocorre usando o mecanismo de canais de plataforma, como descrito
anteriormente.

No momento, as visualizações de plataforma não estão disponíveis para plataformas
de desktop, mas esta não é uma limitação arquitetônica; o suporte pode ser adicionado
no futuro.

### Hospedando conteúdo Flutter em um aplicativo pai

O inverso do cenário anterior é incorporar um widget Flutter em um aplicativo
Android ou iOS existente. Como descrito em uma seção anterior, um aplicativo
Flutter recém-criado rodando em um dispositivo móvel é hospedado em uma activity
Android ou `UIViewController` do iOS. O conteúdo Flutter pode ser incorporado a
um aplicativo Android ou iOS existente usando a mesma API de incorporação.

O template do módulo Flutter é projetado para fácil incorporação; você pode
incorporá-lo como uma dependência de origem em uma definição de build Gradle ou
Xcode existente, ou pode compilá-lo em um binário Android Archive ou iOS Framework
para uso sem exigir que todos os desenvolvedores tenham o Flutter instalado.

O engine Flutter leva um curto período para inicializar, pois ele precisa carregar
as bibliotecas compartilhadas do Flutter, inicializar o runtime Dart, criar e
executar um isolado Dart, e anexar uma superfície de renderização à UI. Para
minimizar quaisquer atrasos na UI ao apresentar conteúdo Flutter, é melhor
inicializar o engine Flutter durante a sequência geral de inicialização do
aplicativo, ou pelo menos antes da primeira tela Flutter, para que os usuários não
experimentem uma pausa súbita enquanto o primeiro código Flutter está sendo
carregado. Além disso, separar o engine Flutter permite que ele seja reutilizado em
múltiplas telas Flutter e compartilhe a sobrecarga de memória envolvida no
carregamento das bibliotecas necessárias.

Mais informações sobre como o Flutter é carregado em um aplicativo Android ou
iOS existente podem ser encontradas no tópico
[Sequência de carregamento, desempenho e memória](/add-to-app/performance).

## Suporte do Flutter para Web

Embora os conceitos arquitetônicos gerais se apliquem a todas as plataformas que
o Flutter suporta, existem algumas características únicas do suporte do Flutter
para Web que são dignas de nota.

O Dart tem sido compilado para JavaScript desde que a linguagem existe, com uma
cadeia de ferramentas otimizada para fins de desenvolvimento e produção.
Muitos aplicativos importantes compilam de Dart para JavaScript e rodam em
produção hoje, incluindo as [ferramentas de publicidade para o Google Ads](https://ads.google.com/home/).
Como o framework Flutter é escrito em Dart, compilá-lo para JavaScript foi
relativamente simples.

No entanto, o engine Flutter, escrito em C++, é projetado para interagir com o
sistema operacional subjacente em vez de um navegador web.
Uma abordagem diferente é, portanto, necessária.

Na Web, o Flutter oferece dois renderizadores:

<table class="table table-striped">
<tr>
<th>Renderizador</th>
<th>Alvo de compilação</th>
</tr>

<tr>
<td>CanvasKit
</td>
<td>JavaScript
</td>
</tr>

<tr>
<td>Skwasm
</td>
<td>WebAssembly
</td>
</tr>
</table>

_Modos de build_ são opções de linha de comando que ditam
quais renderizadores estão disponíveis quando você executa o aplicativo.

O Flutter oferece dois _modos de build_:

<table class="table table-striped">
<tr>
<th>Modo de build</th>
<th>Renderizador(es) disponível(is)</th>
</tr>

<tr>
<td>padrão</td>
<td>CanvasKit</td>
</tr>

<tr>
<td>`--wasm`</td>
<td>Skwasm (preferencial), CanvasKit (fallback)</td>
</tr>
</table>


O modo padrão torna apenas o renderizador CanvasKit disponível.
A opção `--wasm` torna ambos os renderizadores disponíveis,
e escolhe o engine com base nas capacidades do navegador:
preferindo Skwasm se o navegador for capaz de executá-lo,
e recorrendo ao CanvasKit caso contrário.

{% comment %}
O código fonte do draw.io para a imagem a seguir está em /diagrams/resources
{% endcomment %}

![Arquitetura do Flutter para Web](/assets/images/docs/arch-overview/web-framework-diagram.png){:width="80%" .diagram-wrap}

Talvez a diferença mais notável em comparação com outras
plataformas em que o Flutter roda é que não há necessidade
para o Flutter fornecer um runtime Dart.
Em vez disso, o framework Flutter (juntamente com qualquer código que você escreva)
é compilado para JavaScript.
Também vale a pena notar que o Dart tem pouquíssimas diferenças
semânticas de linguagem em todos os seus modos
(JIT versus AOT, compilação nativa versus web),
e a maioria dos desenvolvedores nunca escreverá uma linha de código que
encontre tal diferença.

Durante o tempo de desenvolvimento, o Flutter web usa
[`dartdevc`]({{site.dart-site}}/tools/dartdevc),
um compilador que suporta compilação incremental e, portanto,
permite hot restart e
[hot reload atrás de um flag][hot reload behind a flag].
Inversamente, quando você estiver pronto para criar um aplicativo de produção
para a web, [`dart2js`]({{site.dart-site}}/tools/dart2js),
o compilador JavaScript de produção altamente otimizado do Dart é usado,
empacotando o núcleo e o framework Flutter junto com seu
aplicativo em um arquivo de origem minificado que
pode ser implantado em qualquer servidor web.
O código pode ser oferecido em um único arquivo ou dividido
em vários arquivos através de [imports deferidos][deferred imports].

Para mais informações sobre o Flutter para Web, confira
[Suporte para Web no Flutter][Web support for Flutter] e [Renderizadores Web][Web renderers].

[deferred imports]: {{site.dart-site}}/language/libraries#lazily-loading-a-library
[Web renderers]: /platform-integration/web/renderers
[Web support for Flutter]: /platform-integration/web

## Informações adicionais

Para aqueles interessados em mais informações sobre os internos do Flutter,
o whitepaper [Inside Flutter](/resources/inside-flutter)
fornece um guia útil para a filosofia de design do framework.

[^1]: Embora a função `build` retorne uma árvore nova,
você só precisa retornar algo _diferente_ se
houver alguma nova configuração a ser incorporada.
Se a configuração for de fato a mesma,
você pode simplesmente retornar o mesmo widget.
[^2]: Esta é uma pequena simplificação para facilitar a leitura.
Na prática, a árvore pode ser mais complexa.
[^3]: Existem algumas limitações com essa abordagem, por exemplo,
transparência não compõe da mesma forma para uma visualização de plataforma como
faria para outros widgets Flutter.
[^4]: Um exemplo são as sombras, que precisam ser aproximadas com
primitivas equivalentes ao DOM ao custo de alguma fidelidade.
