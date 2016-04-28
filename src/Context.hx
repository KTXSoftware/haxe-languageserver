import jsonrpc.Protocol;
import js.node.Fs;
import js.node.Path;
import vscode.ProtocolTypes;

class Context {
    public var workspacePath(default,null):String;
    public var displayArguments(default,null):Array<String>;
    public var protocol(default,null):vscode.Protocol;
    public var haxeServer(default,null):HaxeServer;
    public var documents(default,null):TextDocuments;
    var diagnostics:features.DiagnosticsFeature;

    static inline var HAXE_SERVER_PORT = 6000;

    public function new(protocol) {
        this.protocol = protocol;
        protocol.onInitialize = onInitialize;
        protocol.onShutdown = onShutdown;
        protocol.onDidChangeConfiguration = onDidChangeConfiguration;
        protocol.onDidOpenTextDocument = onDidOpenTextDocument;
        protocol.onDidSaveTextDocument = onDidSaveTextDocument;
    }

    function onInitialize(params:InitializeParams, token:RequestToken, resolve:InitializeResult->Void, reject:RejectDataHandler<InitializeError>) {
        workspacePath = params.rootPath;

        haxeServer = new HaxeServer();
        haxeServer.start(findHaxe(workspacePath, params.initializationOptions.kha), HAXE_SERVER_PORT, token, function(error) {
            if (error != null)
                return reject(jsonrpc.JsonRpc.error(0, error, {retry: false}));

            documents = new TextDocuments(protocol);

            new features.CompletionFeature(this);
            new features.HoverFeature(this);
            new features.SignatureHelpFeature(this);
            new features.GotoDefinitionFeature(this);
            new features.FindReferencesFeature(this);
            new features.DocumentSymbolsFeature(this);

            diagnostics = new features.DiagnosticsFeature(this);

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
        });
    }

    function onShutdown(token:RequestToken, resolve:Void->Void, reject:RejectHandler) {
        haxeServer.stop();
        haxeServer = null;
        return resolve();
    }

    function onDidChangeConfiguration(config:DidChangeConfigurationParams) {
        var config:Config = config.settings.haxe;
        displayArguments = config.displayArguments;
    }

    function onDidOpenTextDocument(event:DidOpenTextDocumentParams) {
        documents.onDidOpenTextDocument(event);
        diagnostics.getDiagnostics(event.textDocument.uri);
    }

    function onDidSaveTextDocument(event:DidSaveTextDocumentParams) {
        documents.onDidSaveTextDocument(event);
        diagnostics.getDiagnostics(event.textDocument.uri);
    }
    
    static function findHaxe(projectDir:String, kha:String):String {
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
        
        var localPath = Path.join(projectDir, "Kha", "Tools", "Haxe");
        try {
            if (Fs.statSync(localPath).isDirectory()) {
                return Path.join(localPath, "haxe" + executableExtension);
            }
        }
        catch (error:Dynamic) {
            var globalPath = Path.join(kha, "Tools", "Haxe");
            try {
                if (Fs.statSync(globalPath).isDirectory()) {
                    return Path.join(globalPath, "haxe" + executableExtension);
                }
            }
            catch (error:Dynamic) {
            
            }
        }
        return "";
    }
}

private typedef Config = {
    var displayArguments:Array<String>;
}
