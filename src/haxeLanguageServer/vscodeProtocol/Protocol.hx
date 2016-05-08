package haxeLanguageServer.vscodeProtocol;

@:build(haxeLanguageServer.vscodeProtocol.ProtocolMacro.build())
class Protocol extends jsonrpc.Protocol {
    override function logError(message:String) {
        sendLogMessage({type: Warning, message: message});
    }
}
