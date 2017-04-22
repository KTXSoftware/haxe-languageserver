package haxeLanguageServer.features;

import haxeLanguageServer.helper.ArgumentNameHelper;
import haxeLanguageServer.helper.TypeHelper;

class CodeGenerationFeature {
    private var context:Context;

    public function new(context:Context) {
        this.context = context;
        context.registerCodeActionContributor(generateAnonymousFunction);
        #if debug
        context.registerCodeActionContributor(extractVariable);
        #end
    }

    function generateAnonymousFunction(params:CodeActionParams):Array<Command> {
        var currentSignature = context.signatureHelp.currentSignature;
        if (currentSignature == null || currentSignature.params.textDocument.uri != params.textDocument.uri) return [];

        var help = currentSignature.help;
        var activeParam = help.signatures[help.activeSignature].parameters[help.activeParameter];
        if (activeParam == null) return [];

        var position = currentSignature.params.position;
        var currentType = TypeHelper.parseFunctionArgumentType(activeParam.label);
        switch (currentType) {
            case DTFunction(args, ret):
                var names = ArgumentNameHelper.guessArgumentNames([for (arg in args) arg.type]);
                for (i in 0...args.length) args[i].name = names[i];

                var generatedCode = TypeHelper.printFunctionDeclaration(args, ret, context.config.codeGeneration.functions.anonymous) + " ";
                return new ApplyFixesCommand("Generate anonymous function", params,
                        [{range: position.toRange(), newText: generatedCode}]);
            case _:
                return [];
        }
    }

    function extractVariable(params:CodeActionParams):Array<Command> {
        var range = params.range;
        if (range.isEmpty()) return [];

        var doc = context.documents.get(params.textDocument.uri);
        var startLine = range.start.line;
        var indent = doc.indentAt(startLine);
        var extraction = extractRange(doc, range);
        var variable = '${indent}var $$ = $extraction;\n';
        var insertRange = {line: startLine, character: 0}.toRange();

        return new ApplyFixesCommand("Extract variable", params,
            [{range: insertRange, newText: variable}, {range: range, newText: "$"}]);
    }

    /**
        Extracts text from a range in the document, while being smart about not including:
            - leading/trailing whitespace
            - trailing semicolons
    **/
    function extractRange(doc:TextDocument, range:Range):String {
        var text = doc.getText(range).replace("$", "\\$");

        if (text.endsWith(";")) {
            text = text.substr(0, text.length - 1);
            range.end.character--;
        }

        var ltrimmed = text.ltrim();
        var whitespaceChars = text.length - ltrimmed.length;
        range.start.character += whitespaceChars;
        text = ltrimmed;

        var rtrimmed = text.rtrim();
        whitespaceChars = text.length - rtrimmed.length;
        range.end.character -= whitespaceChars;
        text = rtrimmed;

        return text;
    }
}
