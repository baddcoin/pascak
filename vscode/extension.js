// Pascak VSCode Extension — LSP Client
// Spawns `pascak_noASTnet --lsp` as stdio subprocess.

const vscode = require('vscode');
const { LanguageClient, TransportKind } = require('vscode-languageclient/node');

let client = null;

function activate(context) {
    const config = vscode.workspace.getConfiguration('pascak');
    const serverPath = config.get('serverPath', 'pascak_noASTnet');
    const enableLSP = config.get('enableLSP', true);

    if (!enableLSP) {
        console.log('[pascak] LSP disabled via pascak.enableLSP setting');
        return;
    }

    // Server options: spawn 'pascak_noASTnet --lsp' via stdio
    const serverOptions = {
        command: serverPath,
        args: ['--lsp'],
        transport: TransportKind.stdio,
        options: {
            // Ensure we don't inherit conflicting env vars
            env: { ...process.env }
        }
    };

    // Client options: bind to .pascak / .psk files
    const clientOptions = {
        documentSelector: [
            { scheme: 'file', language: 'pascak' }
        ],
        synchronize: {
            fileEvents: vscode.workspace.createFileSystemWatcher('**/*.{pascak,psk}')
        },
        // Silent startup failures — log to VSCode output channel
        outputChannelName: 'Pascak LSP'
    };

    client = new LanguageClient(
        'pascak',
        'Pascak Language Server',
        serverOptions,
        clientOptions
    );

    // Start the client — also launches the server
    try {
        client.start();
        context.subscriptions.push(client);
        console.log('[pascak] LSP client started (server: ' + serverPath + ')');
    } catch (err) {
        vscode.window.showErrorMessage(
            'Pascak LSP failed to start: ' + err.message +
            '\n\nCheck "pascak.serverPath" setting. Current value: ' + serverPath
        );
        console.error('[pascak] LSP start error:', err);
    }
}

function deactivate() {
    if (!client) {
        return undefined;
    }
    return client.stop();
}

module.exports = { activate, deactivate };
