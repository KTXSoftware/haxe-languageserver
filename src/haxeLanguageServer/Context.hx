package haxeLanguageServer;

import jsonrpc.CancellationToken;
import jsonrpc.ResponseError;
import jsonrpc.Types;
import vscodeProtocol.Protocol;
import vscodeProtocol.Types;
import haxeLanguageServer.features.*;
import js.node.Fs;
import js.node.Path;

private typedef Config = {
    var displayConfigurations:Array<Array<String>>;
    var enableDiagnostics:Bool;
    var displayServerArguments:Array<String>;
}

private typedef InitOptions = {
    var displayConfigurationIndex:Int;
}

class Context {
    public var workspacePath(default,null):String;
    public var haxePath(default,null):String;
    public var displayArguments(get,never):Array<String>;
    public var protocol(default,null):Protocol;
    public var haxeServer(default,null):HaxeServer;
    public var documents(default,null):TextDocuments;
    var diagnostics:DiagnosticsFeature;

    @:allow(haxeLanguageServer.HaxeServer)
    var config:Config;
    var displayConfigurationIndex:Int;

    inline function get_displayArguments() return config.displayConfigurations[displayConfigurationIndex];

    public function new(protocol) {
        this.protocol = protocol;

        haxeServer = new HaxeServer(this);

        protocol.onInitialize = onInitialize;
        protocol.onShutdown = onShutdown;
        protocol.onDidChangeConfiguration = onDidChangeConfiguration;
        protocol.onDidOpenTextDocument = onDidOpenTextDocument;
        protocol.onDidSaveTextDocument = onDidSaveTextDocument;
        protocol.onVSHaxeDidChangeDisplayConfigurationIndex = onDidChangeDisplayConfigurationIndex;
    }

    function onInitialize(params:InitializeParams, token:CancellationToken, resolve:InitializeResult->Void, reject:ResponseError<InitializeError>->Void) {
        workspacePath = params.rootPath;
        haxePath = findHaxe(params.initializationOptions.kha);
        displayConfigurationIndex = (params.initializationOptions : InitOptions).displayConfigurationIndex;
        documents = new TextDocuments(protocol);
        return resolve({
            capabilities: {
                textDocumentSync: TextDocuments.syncKind,
                completionProvider: {
                    triggerCharacters: ["."]
                },
                signatureHelpProvider: {
                    triggerCharacters: ["(", ","]
                },
                definitionProvider: true,
                hoverProvider: true,
                referencesProvider: true,
                documentSymbolProvider: true,
                codeActionProvider: true
            }
        });
    }

    function onDidChangeDisplayConfigurationIndex(params:{index:Int}) {
        displayConfigurationIndex = params.index;
        haxeServer.restart("selected configuration was changed");
    }

    function onShutdown(_, token:CancellationToken, resolve:NoData->Void, _) {
        haxeServer.stop();
        haxeServer = null;
        return resolve(null);
    }

    function onDidChangeConfiguration(newConfig:DidChangeConfigurationParams) {
        var firstInit = (config == null);

        config = newConfig.settings.haxe;

        if (firstInit) {
            haxeServer.start(haxePath, function() {
                new CompletionFeature(this);
                new HoverFeature(this);
                new SignatureHelpFeature(this);
                new GotoDefinitionFeature(this);
                new FindReferencesFeature(this);
                new DocumentSymbolsFeature(this);

                diagnostics = new DiagnosticsFeature(this);
                if (config.enableDiagnostics) {
                    for (doc in documents.getAll())
                        diagnostics.getDiagnostics(doc.uri);
                }
            });
        } else {
            haxeServer.restart("configuration was changed");
        }
    }

    function onDidOpenTextDocument(event:DidOpenTextDocumentParams) {
        documents.onDidOpenTextDocument(event);
        if (diagnostics != null && config.enableDiagnostics)
            diagnostics.getDiagnostics(event.textDocument.uri);
    }

    function onDidSaveTextDocument(event:DidSaveTextDocumentParams) {
        documents.onDidSaveTextDocument(event);
        if (diagnostics != null && config.enableDiagnostics)
            diagnostics.getDiagnostics(event.textDocument.uri);
    }
    
    static function findHaxe(kha:String):String {
        var executableExtension:String;
        if (js.Node.process.platform == "win32") {
            executableExtension = ".exe";
        } else if (js.Node.process.platform == "linux") {
            if (js.Node.process.arch == "x64") {
                executableExtension = "-linux64";
            } else if (js.Node.process.arch == "arm") {
                executableExtension = "-linuxarm";
            } else {
                executableExtension = "-linux32";
            }
        } else {
            executableExtension = "-osx";
        }
        
        return Path.join(kha, "Tools", "haxe", "haxe" + executableExtension);
    }
}
