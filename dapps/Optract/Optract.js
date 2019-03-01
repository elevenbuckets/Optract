'use strict';

const ethUtils = require('ethereumjs-utils');
const BladeIronClient = require('bladeiron_api'); // 11BE BladeIron Client API

class Optract extends BladeIronClient {
	constructor(rpcport, rpchost, options)
        {
		super(rpcport, rpchost, options);
	        this.ctrName = 'OptractRegistry';

                this.createOptract = (ethAmount, totalPrice, period) => 
		{
			return this.queryInitPrice().then((tokenAmount) => 
			{
                       		return this.manualGasBatch(2000000)(
					this.Tk('DAI')('approve')(this.ctrAddrBook['OptractRegistry'], tokenAmount)(),
                                        this.Tk(this.ctrName)('createOptract')(ethAmount, totalPrice, period)()
				).then((QID) => 
				{
					return this.getReceipts(QID).then((QIDlist) => { return {[QID]: QIDlist} });
                              	});
			});
                }

                this.queryInitPrice = () => { return this.call(this.ctrName)('queryInitPrice')() }

                this.isExpired = (optractAddr) => 
		{
                        return this.call(this.ctrName)('isExpired')(optractAddr).then((rc) => {return(rc)});
                }

                this.activeOptracts = (start, length, ownerAddr = '0x0') => 
		{
                        console.log("LOG: return arrays:");
                        console.log("     addr, expiretime (unix time in sec), total price of ETH (DAI), ETH amount, option price (DAI), filled(bool)");
                        return this.call(this.ctrName)('activeOptracts')(start, length, ownerAddr).then((rc) => {
                                return rc;
                        })
                }

                this.inactiveOptracts = (start, length, ownerAddr = '0x0') =>
		{
                        console.log("LOG: return arrays:");
                        console.log("     addr, expiretime (unix time in sec), total price of ETH (DAI), ETH amount, option price (DAI), filled(bool)");
                        return this.call(this.ctrName)('inactiveOptracts')(start, length, ownerAddr).then((rc) => {
                                return rc;
                        })
                }

                /*
                   below are optract related functions, assume already bind an optract by "app.Optract.connectABI()"
                */
                this.fillInEth = (ctrName) =>
                {
                        if (! ctrName in this.ctrAddrBook ) throw "contract not found";
                        return this.call(ctrName)('ethAmount')().then((ethAmount) => {
                                return this.sendTk(ctrName)('fillInEth')()(ethAmount).then((qid) => {
                                        return qid;
                                })
                        })
                }

                this.exercise = (ctrName) =>
                {
                        if (! ctrName in this.ctrAddrBook ) throw "contract not found";
                        return this.call(ctrName)('actionTime')().then((time) =>{
                                if (time - Math.floor(Date.now()/1000) < 600) {throw "too soon";}
                                return this.call(ctrName)('totalPriceInDai')().then((tokenAmount) => 
                                {
                                        return this.manualGasBatch(2000000)(
                                                this.Tk('DAI')('approve')(this.ctrAddrBook[ctrName], tokenAmount)(),
                                                this.Tk(ctrName)(currentOwnerExercise)()()
                                        ).then((QID) => 
                                        {
                                                return this.getReceipts(QID).then((QIDlist) => { return {[QID]: QIDlist} });
                                        });
                                });
                        }) 
                }

                this.claimOptract = (ctrName) =>
                {
                        if (! ctrName in this.ctrAddrBook ) throw "contract not found";
                        // todo: obtain proof, isLeft, targetLeat, merkleRoot
                        let [proof, isLeft, targetLeat, merkleRoot] = [[], [], '0x0', '0x0'];
                        return this.call(ctrName)('optionPrice')().then((tokenAmount) => {
                                return this.manualGasBatch(2000000)(
                                        this.Tk('DAI')('approve')(this.ctrAddrBook[ctrName], tokenAmount + tokenAmount/500)(),
                                        this.Tk(ctrName)('claimOptract')(proof, isLeft, targetLeat, merkleRoot)()
                                ).then((QID) =>
                                {
                                        return this.getReceipts(QID).then((QIDlist) => { return {[QID]: QIDlist} });
                                });
                        })
                }
        }
}

module.exports = Optract;
