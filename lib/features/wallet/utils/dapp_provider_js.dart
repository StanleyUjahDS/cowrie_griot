class DAppProviderJs {
  static const String providerJs = '''
(function() {
    const address = "%ADDRESS%";
    const chainId = "%CHAIN_ID%";
    const rpcUrl = "%RPC_URL%";

    function GriotProvider() {
        this.isMetaMask = true;
        this.isGriot = true;
        this._chainId = chainId;
        this.networkVersion = parseInt(chainId, 16).toString();
        this.selectedAddress = address;
        this.isConnected = () => true;
        
        this._events = {};

        Object.defineProperty(this, 'chainId', {
            get: () => this._chainId,
            set: (val) => {
                this._chainId = val;
                this.networkVersion = parseInt(val, 16).toString();
                if (this.emit) {
                    this.emit('chainChanged', val);
                    this.emit('networkChanged', this.networkVersion);
                }
            }
        });

        this.request = async (request) => {
            console.log("Griot DApp Request:", request.method, request.params);
            
            // Forward to Flutter
            const response = await window.flutter_inappwebview.callHandler('ethereum_request', request);
            
            if (response && response.error) {
                throw response.error;
            }
            
            return response.result;
        };

        // Legacy support
        this.enable = async () => {
            return await this.request({ method: 'eth_requestAccounts' });
        };

        this.send = (method, params) => {
            if (typeof method === 'string') {
                return this.request({ method, params });
            }
            return this.request(method);
        };

        this.on = (event, callback) => {
            if (!this._events[event]) this._events[event] = [];
            this._events[event].push(callback);
            return this;
        };

        this.removeListener = (event, callback) => {
            if (!this._events[event]) return this;
            this._events[event] = this._events[event].filter(cb => cb !== callback);
            return this;
        };

        this.emit = (event, ...args) => {
            if (!this._events[event]) return false;
            this._events[event].forEach(cb => cb(...args));
            return true;
        };
    }

    const provider = new GriotProvider();

    // Standard Injected Provider
    window.ethereum = provider;
    window.web3 = { currentProvider: provider };
    
    // EIP-6963: Multi Injected Provider Discovery
    function announceProvider() {
      const info = {
        uuid: "6f52e25a-4b2a-45c1-840f-79177a3d1b64",
        name: "Griot Wallet",
        icon: "%ICON%",
        rdns: "network.griot.wallet"
      };
      
      window.dispatchEvent(
        new CustomEvent("eip6963:announceProvider", {
          detail: Object.freeze({ info, provider })
        })
      );
    }

    window.addEventListener("eip6963:requestProvider", announceProvider);
    announceProvider();

    // Dispatch legacy initialized event
    window.dispatchEvent(new Event('ethereum#initialized'));
    console.log("Griot Web3 Provider Injected and Announced");
})();
''';
}
