'use strict';

// const fs   = require('fs');
// const path = require('path');
const ethUtils = require('ethereumjs-utils');
const biapi = require('bladeiron_api');
// const mkdirp = require('mkdirp');

// 11BE BladeIron Client API
const BladeIronClient = require('bladeiron_api');

// Functional
const comprise = (...fns) => args => { return fns.reduce((r,f) => {return f(r)}, args); };

class Optract extends BladeIronClient {
	constructor(rpcport, rpchost, options)
        {
		super(rpcport, rpchost, options);
	        this.ctrName = 'OptractRegistry';

		this.Tk = (ctrName) => (callName) => (...args) => (amount = null) => (jobList = []) => 
		{
			return [ ...jobList, this.getTkObj(ctrName)(callName)(...args)(amount) ]
		}

		this.manualGasBatch = (gasAmount) => (...fns) =>
		{
			this.gasAmount = gasAmount;
			let p = comprise(...fns)();
			return Promise.all(p).then((jobList) => { return this.processJobs(jobList) })
		}

                this.createOptract = (ethAmount, totalPrice, period) => {
			return this.queryInitPrice().then((tokenAmount) => {
				console.log(`DEBUG: initPrice = ${tokenAmount}`);
                       		return this.manualGasBatch(2000000)(
					this.Tk('DAI')('approve')(this.ctrAddrBook['OptractRegistry'], tokenAmount)(),
                                        this.Tk(this.ctrName)('createOptract')(ethAmount, totalPrice, period)()
				).then((QID) => {
					console.log(`DEBUG: gasAmount after processJobs: ${this.gasAmount}`);
					return this.getReceipts(QID).then((QIDlist) => {
                            		        if (QIDlist[0].status !== '0x1') throw "failed to approve";
                                              	if (QIDlist[1].status !== '0x1') throw "failed to create optract";
                            		        return {'QIDlist': QIDlist, 'txHash': QIDlist[1].transactionHash};
                                      	});
                              	});
			});
                }

                this.queryInitPrice = () => {
                        return this.call(this.ctrName)('queryInitPrice')().then((rc) => {
				return rc;
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
