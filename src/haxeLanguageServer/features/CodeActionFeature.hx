package haxeLanguageServer.features;

import jsonrpc.CancellationToken;
import jsonrpc.ResponseError;
import jsonrpc.Types.NoData;
import languageServerProtocol.Types;

typedef CodeActionContributor = CodeActionParams->Array<Command>;

class CodeActionFeature {
    var context:Context;
    var contributors:Array<CodeActionContributor> = [];

    public function new(context:Context) {
        this.context = context;
        context.protocol.onRequest(Methods.CodeAction, onCodeAction);
    }

    public function registerContributor(contributor:CodeActionContributor) {
        contributors.push(contributor);
    }

    function onCodeAction(params:CodeActionParams, token:CancellationToken, resolve:Array<Command>->Void, reject:ResponseError<NoData>->Void) {
        var codeActions = [];
        for (contributor in contributors) codeActions = codeActions.concat(contributor(params));
        resolve(codeActions);
    }
}
