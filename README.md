# Infcanvas

基于Flutter的infinite size canvas绘图app

由于default flutter engine不提供操作底层skia资源 (`SkImage`, GPU Backed `SkCanvas` `SkRuntimeEffect` 等) 的接口，本app使用定制的[flutter engine](https://github.com/0x5b25/infcanvas_flutter)。请[编译](https://github.com/flutter/flutter/wiki/Compiling-the-engine)并[使用](https://github.com/flutter/flutter/wiki/The-flutter-tool#using-a-locally-built-engine-with-the-flutter-tool)该引擎运行本app

由于iOS端的限制，基于JIT的interpreters (`C# Mono`, `dotnet`, even `DartVM`) 无法在apple终端设备上运行，为运行Scriptable Brush Pipeline，我们设计了一个基于[Direct Call Threading](http://www.cs.toronto.edu/~matz/dissertation/matzDissertation-latex2html/node6.html)的解释器，以求resonable的性能和便捷的功能扩展。

目前核心功能（ Visual Scripting, 可编程(Pipelined)笔刷， 无限画布尺寸(由 ArbInt 和 QuadTree 支持) ）均已实现。

## File structure

- `utilities` : Self contained function blocks, no dependencies outside its own folder
    - `async` : async guards, task schedulers, etc.
    - `serializer` : simple object serializer
    - `storage` : Application state saving and loading, amongst other io related functions
- `widgets` : Reusable visual elements
    - `functional` : Parts that serves a specific functional need, like tree view
    - `visual` : Vanilla widgets that are customized visually
- `scripting` : Visual scripting module
    - `editor` : VM Code editor and compilers
    - `shader_editor` : Shader code editor and compilers
- `canvas` : The work horse of the canvas UI system frontends
    - `tools` : Canvas UI tool plugins, like brush system, color palette, canvas viewer. Other tools like line guides, color picker, paint bucket are to be added.
- `brush_manager` : Glue logic between file system and tree viewer widget to  
                 manage brush data saved on disk

## TODO (easy to hard)
- [ ] MORE BRUSH TEMPLATES !
- [ ] Make layer mix mode panel more accessable
- [ ] Distribute brush points evenly along stroke
- [ ] Show thumbnail image in canvas layer manager
- [ ] Canvas viewport anchoring support
- [ ] Static data editor in brush editor
- [ ] Brush test canvas in brush editor
- [ ] Binary image asset support in `BrushData` for things like textures
- [ ] Layer duplication and combining
- [ ] Image import and export
- [ ] **Project file saving, which is the most welcome one**
- [ ] Tempoary file cache in case not enough VRAM on mobile devices
- [ ] Undo/Redo system

## ISSUES

- Canvas viewport zooming mechanism is not accurate enough when lod needs to change
- Increase VM robustness, capture VM errors as complete as possible(No exception support in flutter engine project, sadly ), or the whole application will crash.
- Handle VM null access scenarios during script execution. Maybe exception handling needs to be added to VM?
- Since flutter 2.2, the [cross-context image passing trick](https://github.com/flutter/flutter/issues/44148#issuecomment-549970873) used is no longer working. ~~Currently viewport snapshot images needs to be transfered GPU -> CPU -> GPU to be used from dart safely, which tanked performance.~~ Currently uses SkPictureRecorder to record tree node layout during snapshot generation. Maybe open an issue in flutter repo and ask for help is a good idea.

## Stretch Goals
- Freeform transforming
- Selection and masking
- Cut Copy Paste pixels
- Other sophisticated image processing (e.g. flood fill) tools which requires CPU support
- PSD file format support?
- Custom plugin support, since we already have a VM script runtime for brush pipeline. But a major overhaul of the vm interpreter, a compiler frontend as well as a well-ish defined script language grammar are required.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
