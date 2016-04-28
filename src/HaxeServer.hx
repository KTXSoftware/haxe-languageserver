import js.node.child_process.ChildProcess as ChildProcessObject;
import js.node.Buffer;
import js.node.ChildProcess;
import js.node.Net;
import js.node.net.Socket;
import js.node.stream.Readable;
import jsonrpc.Protocol.RequestToken;
using StringTools;

class HaxeServer {
    var proc:ChildProcessObject;
    var port:Int;
    var version:Array<Int>;
    static var reVersion = ~/^(\d+)\.(\d+)\.(\d+)(?:\s.*)?$/;

    public function new() {
    }

    public function start(haxePath:String, port:Int, token:RequestToken, callback:String->Void) {
        this.port = port;
        stop();
        proc = ChildProcess.spawn(haxePath, ["--wait", "" + port], {stdio: Ignore});
        process(["-version"], token, null, function(data) {
            if (!reVersion.match(data))
                return callback("Error parsing haxe version " + data);

            var major = Std.parseInt(reVersion.matched(1));
            var minor = Std.parseInt(reVersion.matched(2));
            var patch = Std.parseInt(reVersion.matched(3));
            if (major < 3 || minor < 3) {
                callback("Unsupported Haxe version! Minimum version required: 3.3.0");
            } else {
                version = [major, minor, patch];
                callback(null);
            }
        }, token.error);
    }

    public function stop() {
        if (proc != null) {
            proc.kill();
            proc = null;
        }
    }

    public function process(args:Array<String>, token:RequestToken, stdin:String, callback:String->Void, errback:String->Void) {
        if (stdin != null) {
            args.push("-D");
            args.push("display-stdin");
        }
        var socket = Net.connect(port);
        socket.on(SocketEvent.Error, function(e) {
            token.error(ErrorUtils.errorToString(e, "Error while communicating haxe server: "));
        });
        socket.on(SocketEvent.Connect, function() {
            if (token.canceled) {
                socket.end();
                return callback(null);
            }

            for (arg in args)
                socket.write(arg + "\n");
            if (stdin != null) {
                socket.write("\x01");
                socket.write(stdin);
            }
            socket.write("\x00");

            var chunks = [];
            var totalLen = 0;
            socket.on(ReadableEvent.Data, function(buf:Buffer) {
                if (token.canceled) {
                    socket.end();
                    return callback(null);
                }
                chunks.push(buf);
                totalLen += buf.length;
            });
            socket.on(SocketEvent.End, function() {
                if (token.canceled)
                    return callback(null);
                if (totalLen == 0)
                    return callback(""); // no data received - can happen

                var data = Buffer.concat(chunks, totalLen);
                var buf = new StringBuf();
                var hasError = false;
                for (line in data.toString().split("\n")) {
                    switch (line.fastCodeAt(0)) {
                        case 0x01: // print
                            trace("Haxe print:\n" + line.substring(1).replace("\x01", "\n"));
                        case 0x02: // error
                            hasError = true;
                        default:
                            buf.add(line);
                            buf.addChar("\n".code);
                    }
                }

                var data = buf.toString().trim();

                if (hasError)
                    return errback(data);

                try {
                    callback(data);
                } catch (e:Dynamic) {
                    token.error(ErrorUtils.errorToString(e, "Exception while handling haxe completion response: "));
                }
            });
        });
    }
}
