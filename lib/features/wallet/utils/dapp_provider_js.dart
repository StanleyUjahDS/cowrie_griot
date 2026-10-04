class DAppProviderJs {
  static const String providerJs = '''
(function() {
    if (window.ethereum && window.ethereum.isGriot) {
        window.ethereum._setChainId?.("%CHAIN_ID%");
        window.dispatchEvent(new Event("eip6963:requestProvider"));
        return;
    }

    const address = "%ADDRESS%";
    const chainId = "%CHAIN_ID%";

    function GriotProvider() {
        this.isMetaMask = false;
        this.isTrust = false;
        this.isGriot = true;
        
        this._chainId = chainId;
        this.networkVersion = parseInt(chainId, 16).toString();
        this.selectedAddress = %IS_CONNECTED% ? address : null;
        this.isConnected = () => !!this.selectedAddress;
        
        this.autoRefreshOnNetworkChange = false;
        this._events = {};

        Object.defineProperty(this, 'chainId', {
            get: () => this._chainId,
            set: (val) => {
                if (this._chainId === val) return;
                this._chainId = val;
                this.networkVersion = parseInt(val, 16).toString();
                this.emit('chainChanged', val);
                this.emit('networkChanged', this.networkVersion);
            }
        });

        this._setChainId = (val) => {
            const normalized = '0x' + parseInt(String(val), String(val).startsWith('0x') ? 16 : 10).toString(16);
            this.chainId = normalized;
        };

        const _waitForBridge = () => {
            return new Promise((resolve, reject) => {
                if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                    return resolve();
                }
                let attempts = 0;
                const interval = setInterval(() => {
                    attempts++;
                    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                        clearInterval(interval);
                        resolve();
                    } else if (attempts > 50) {
                        clearInterval(interval);
                        resolve(); // Proceed anyway, bridge might just be slow
                    }
                }, 40);
            });
        };

        this.request = async (request) => {
            if (!request || !request.method) return;
            const method = request.method;
            const params = request.params || [];
            
            try {
                await _waitForBridge();
                
                const res = await window.flutter_inappwebview.callHandler('GriotWeb3', {
                    method: method,
                    params: params
                });
                
                if (res && res.error) {
                    const error = new Error(res.error.message || 'Wallet request failed');
                    error.code = res.error.code;
                    error.data = res.error.data;
                    throw error;
                }
                
                const result = res ? res.result : null;

                if (method === 'eth_chainId' && result) {
                    this._setChainId(result);
                }

                if (method === 'eth_requestAccounts' || method === 'eth_accounts' || method === 'wallet_requestPermissions') {
                    let newAddress = null;
                    if (method === 'wallet_requestPermissions' && Array.isArray(result)) {
                        // Extract address from caveats if available
                        const ethAccounts = result.find(p => p.parentCapability === 'eth_accounts');
                        if (ethAccounts && ethAccounts.caveats) {
                            const restrictAccounts = ethAccounts.caveats.find(c => c.type === 'restrictAccounts');
                            if (restrictAccounts && restrictAccounts.value && restrictAccounts.value.length > 0) {
                                newAddress = restrictAccounts.value[0];
                            }
                        }
                    } else {
                        newAddress = (result && result.length > 0) ? result[0] : null;
                    }

                    const addressChanged = this.selectedAddress !== newAddress;
                    if (addressChanged) {
                        this.selectedAddress = newAddress;
                        if (this.selectedAddress) {
                            this.emit('accountsChanged', [this.selectedAddress]);
                            this.emit('connect', { chainId: this._chainId });
                        } else {
                            this.emit('accountsChanged', []);
                        }
                    }
                }
                return result;
            } catch (err) {
                console.error("Griot Bridge Error:", method, err);
                throw err;
            }
        };

        this.enable = async () => {
            return await this.request({ method: 'eth_requestAccounts' });
        };

        this.send = (method, paramsOrCallback) => {
            if (method && typeof method === 'object' &&
                typeof paramsOrCallback === 'function') {
                return this.sendAsync(method, paramsOrCallback);
            }
            if (typeof method === 'string') {
                return this.request({ method, params: paramsOrCallback });
            }
            if (method && typeof method === 'object' && method.method) {
               return this.request(method);
            }
            return this.request({ method: method, params: paramsOrCallback });
        };

        this.sendAsync = (request, callback) => {
            this.request(request)
                .then(res => callback(null, { id: request.id, jsonrpc: "2.0", result: res }))
                .catch(err => callback(err, null));
        };

        this.on = (event, callback) => {
            if (!this._events[event]) this._events[event] = [];
            this._events[event].push(callback);
            
            if (event === 'connect' && this.selectedAddress) {
                setTimeout(() => callback({ chainId: this._chainId }), 0);
            }
            if (event === 'accountsChanged' && this.selectedAddress) {
                setTimeout(() => callback([this.selectedAddress]), 0);
            }
            return this;
        };

        this.removeListener = (event, callback) => {
            if (!this._events[event]) return this;
            this._events[event] = this._events[event].filter(cb => cb !== callback);
            return this;
        };

        this.emit = (event, ...args) => {
            if (!this._events[event]) return false;
            this._events[event].forEach(cb => {
                try { cb(...args); } catch(e) {}
            });
            return true;
        };
    }

    const provider = new GriotProvider();
    const providerUuid = (window.crypto && typeof window.crypto.randomUUID === 'function')
        ? window.crypto.randomUUID()
        : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (character) => {
            const random = Math.floor(Math.random() * 16);
            const value = character === 'x' ? random : ((random & 0x3) | 0x8);
            return value.toString(16);
          });

    // Keep a wallet-specific namespace while retaining the legacy provider
    // globals expected by DApps that do not yet use EIP-6963.
    window.griotEthereum = provider;
    window.ethereum = provider;
    window.ethereum.providers = [provider];
    window.web3 = { currentProvider: provider };

    const providerInfo = Object.freeze({
      uuid: providerUuid,
      name: "Griot Wallet",
      icon: "%ICON%",
      rdns: "network.griot.wallet"
    });
    const providerDetail = Object.freeze({ info: providerInfo, provider });

    function announceProvider() {
      window.dispatchEvent(new CustomEvent("eip6963:announceProvider", {
        detail: providerDetail
      }));
    }

    window.addEventListener("eip6963:requestProvider", announceProvider);
    announceProvider();

    window.dispatchEvent(new Event('ethereum#initialized'));
    console.log("Griot Injected v2.4");
})();
''';
}
