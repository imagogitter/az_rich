targetScope = 'subscription'

param projectName string = 'ai-inference'
param location string = 'eastus'

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: '${projectName}-rg'
  location: location
}
