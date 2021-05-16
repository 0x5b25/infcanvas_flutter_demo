# Infcanvas

基于Flutter的infinite size canvas绘图app

由于default flutter engine不提供操作底层skia资源 (`SkImage`, GPU Backed `SkCanvas` `SkRuntimeEffect` 等) 的接口，本app使用定制的[flutter engine](https://github.com/0x5b25/infcanvas_flutter)。请[编译](https://github.com/flutter/flutter/wiki/Compiling-the-engine)并[使用](https://github.com/flutter/flutter/wiki/The-flutter-tool#using-a-locally-built-engine-with-the-flutter-tool)该引擎运行本app

由于iOS端的限制，基于JIT的interpreters (`C# Mono`, `dotnet`, even `DartVM`) 无法在apple终端设备上运行，为运行Scriptable Brush Pipeline，我们设计了一个基于[Direct Call Threading](http://www.cs.toronto.edu/~matz/dissertation/matzDissertation-latex2html/node6.html)的解释器，以求resonable的性能和便捷的功能扩展。

## File structure

- `utilities` : Self contained function blocks, no dependencies outside its own folder
    - `async` : async guards, task schedulers, etc.
    - `serializer` : simple object serializer
- `widgets` : Reusable visual elements
- `scripting` : Visual scripting module
    - `editor` : VM Code editor and compilers
    - `shader_editor` : Shader code editor and compilers

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
