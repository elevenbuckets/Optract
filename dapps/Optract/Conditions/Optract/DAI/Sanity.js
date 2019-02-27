module.exports =
{
        DAI_approve_sanity(addr, jobObj)
	{
		// approve(toAddr, amount)
		let [ exchange, tokenUnits ] = jobObj.args.map((i) => { return jobObj[i] });
		let gasCost = this.gasCostEst(addr, jobObj.txObj);

		if (
			this.CUE['Optract'][jobObj.contract].balanceOf(addr).gte(Number(tokenUnits))
		     && this.web3.eth.getBalance(addr).gte(gasCost)
		   ) {
			    return true;
		   } else {
                            console.log('WARNING: condition failed!');
                            console.dir(jobObj);
                            console.log('debuggg: tokens:' + tokenUnits);
                            return false;
		   }
	},

        DAI_transfer_sanity(addr, jobObj) 
	{
		// transfer(toAddr,amount)
		let [ exchange, tokenUnits ] = jobObj.args.map((i) => { return jobObj[i] });
		let gasCost = this.gasCostEst(addr, jobObj.txObj);

		if (
			this.CUE['Optract'][jobObj.contract].balanceOf(addr).gte(Number(tokenUnits))
		     && this.web3.eth.getBalance(addr).gte(gasCost)
		) {
			return true;
		} else {
			return false;
		}
        },

        DAI_transferFrom_sanity(addr, jobObj) 
	{
		// transferFrom(fromAddr,toAddr,amount)
	        // add something here? 
                return true;
        },

        DAI_allowance_sanity(addr, jobObj)
        {
                return true;
        }
}
