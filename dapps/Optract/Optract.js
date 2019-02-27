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
                        if (typeof(this.initialPayment) === 'undefined') {
                                return this.queryInitPrice().then( () => {
                                        return this.sendTk('DAI')('approve')(this.ctrAddrBook['OptractRegistry'], this.initialPayment)().then((qid1)=>{
					        console.log(`DEBUG: QID1 = ${qid1}`);
                                                return this.sendTk(this.ctrName)('createOptract')(ethAmount, totalPrice, period)().then((qid2) => {
					                console.log(`DEBUG: QID2 = ${qid2}`);
                                                }).catch((err)=>{console.trace(err)})
                                        }).catch((err)=>{console.trace(err)})
                                })
                        } else {
                                return this.sendTk('DAI')('approve')(this.ctrAddrBook['OptractRegistry'], this.initialPayment)().then((qid1)=>{
					console.log(`DEBUG: QID = ${qid1}`);
                                        return this.sendTk(this.ctrName)('createOptract')(ethAmount, totalPrice, period)().then((qid2) => {
					        console.log(`DEBUG: QID = ${qid2}`);
                                        })
                                })
                        }
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
