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
                        return this.sendTk('ERC20')('approve')(optractAddr, valueDai)().then(()=>{
                                return this.sendTk(this.ctrName)('createOptract')(ethAmount, totalPrice, period).then((rc) => {
                                        console.log(rc)
                                })
                        })
                }

                this.queryInitPrice = () => {
                        this.initialPayment = this.call(this.ctrName)('queryInitPrice')().then((rc) => {return(rc)});
                        return this.initialPayment;
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
