const CollectiveInvestmentScheme = artifacts.require("CollectiveInvestmentScheme");
module.exports = function (deployer) {
  deployer.deploy(CollectiveInvestmentScheme);
};
