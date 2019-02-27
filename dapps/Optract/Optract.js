'use strict';

// const fs   = require('fs');
// const path = require('path');
const ethUtils = require('ethereumjs-utils');
const biapi = require('bladeiron_api');
// const mkdirp = require('mkdirp');

// 11BE BladeIron Client API
const BladeIronClient = require('bladeiron_api');

class Optract extends BladeIronClient {
	constructor(rpcport, rpchost, options)
        {
		super(rpcport, rpchost, options);
	        this.ctrName = 'OptractRegistry';

                this.createOptract = (ethAmount, totalPrice, period) => {
                        let p = [
                                typeof(this.initialPayment) === 'undefined' ? this.queryInitPrice() : this.initialPayment,
                                this.getTkObj('DAI')('approve')(this.ctrAddrBook['OptractRegistry'], this.initialPayment)(),
                                this.getTkObj(this.ctrName)('createOptract')(ethAmount, totalPrice, period)()
                        ];
                        return Promise.all(p).then((plist) => {
                                return this.processJobs(plist.slice(1));
                        })
                }

                this.queryInitPrice = () => {
                        return this.call(this.ctrName)('queryInitPrice')().then((rc) => {
                                this.initialPayment = rc
                        })
                }

                this.isExpired = (optractAddr) => {
                        return this.call(this.ctrName)('isExpired')(optractAddr).then((rc) => {return(rc)});
                }

                this.activeOptracts = (start, length, ownerAddr) => {
                        return this.call(this.ctrName)('activeOptracts')(start, length, ownerAddr).then((rc) => {return(rc)});
                }

        }
}

module.exports = Optract;
