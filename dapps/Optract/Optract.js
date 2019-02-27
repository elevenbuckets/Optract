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
                                return this.processJobs(plist.slice(1)).then((QID) => {
					return this.getReceipts(QID).then((QIDlist) => {
                                                if (QIDlist[0].status !== '0x1') throw "failed to approve";
                                                if (QIDlist[1].status !== '0x1') throw "failed to create optract";
                                                return {'QIDlist': QIDlist, 'txHash': QIDlist[1].transactionHash};
                                        });
                                })
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
                        return this.call(this.ctrName)('activeOptracts')(start, length, ownerAddr).then((rc1) => {
                                return this.call(this.ctrName)('activeOptractsFilledStatus')(start, length, ownerAddr).then((rc2) => {
                                        // compare rc1[0] and rc2[0], i.e., the address of contracts
                                        if (rc1[0].length === rc2[0].length && rc1[0].every(function(value, index) { return value === rc2[0][index]})) {
                                                rc1.push(rc2[1]);  // rc2[1] is the "filled" status
                                        } else {
                                                console.log("error in query filled status, skip that part")
                                        }
                                        return rc1;
                                })
                        })
                }

        }
}

module.exports = Optract;
