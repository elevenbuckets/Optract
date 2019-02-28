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
			let p = [
					this.call(this.ctrName)('activeOptracts')(start, length, ownerAddr),
					this.call(this.ctrName)('activeOptractsFilledStatus')(start, length, ownerAddr)
				];

                        return Promise.all(p).then((rc) => {
				let rc1 = rc[0]; let rc2 = rc[1];
                                // compare rc1[0] and rc2[0], i.e., the address of contracts
                                if (rc1[0].length === rc2[0].length && rc1[0].every(function(value, index) { return value === rc2[0][index]})) {
                                        rc1.push(rc2[1]);  // rc2[1] is the "filled" status
                                } else {
                                        console.log("DEBUG: error in query filled status, skip that part")
                                }
                                return rc1;
                        })
                }
        }
}

module.exports = Optract;
