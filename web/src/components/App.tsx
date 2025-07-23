import { BackgroundImage, MantineProvider } from '@mantine/core';
import React, { useEffect, useState } from "react";
import theme from '../theme';
import { isEnvBrowser } from '../utils/misc';
import "./App.css";
import { UI } from './UI/main';
import WeaponRepair from './UI/WeaponRepair';
import useAppVisibilityStore from '../stores/appVisibilityStore';
import useRepairStore from '../stores/repairStore';

const App: React.FC = () => {
  const { showApp, setVisibility } = useAppVisibilityStore();
  const { showRepair, setRepairVisibility, setRepairData } = useRepairStore();
  const [craftingData, setCraftingData] = useState<any>(null);



  // Handle NUI events at App level
  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      const { action, data } = event.data;
      
      switch (action) {
        case 'UPDATE_VISIBILITY':
          // Only show crafting UI if repair is not active
          if (!showRepair) {
            setVisibility(data);
          }
          break;
          
        case 'OPEN_CRAFTING':
          setCraftingData(data);
          setRepairVisibility(false); // Ensure repair is closed
          break;
          
        case 'OPEN_REPAIR':
          setRepairData(data);
          setRepairVisibility(true);
          setVisibility(false); // Hide crafting UI immediately
          break;
          
        case 'CLOSE_REPAIR':
          setRepairVisibility(false);
          setRepairData(null);
          setVisibility(false); // Also hide the main UI
          break;
          
        case 'hideApp':
          setRepairVisibility(false);
          setRepairData(null);
          setVisibility(false);
          break;
          
        case 'closeRepair':
          setRepairVisibility(false);
          setRepairData(null);
          setVisibility(false);
          break;
      }
    };
    
    window.addEventListener('message', handleMessage);
    
    return () => {
      window.removeEventListener('message', handleMessage);
    };
  }, [setVisibility, setRepairVisibility, setRepairData]);

  return (  
    <MantineProvider theme={theme} defaultColorScheme='dark'>
      <Wrapper>
        {showApp && !showRepair && <UI initialData={craftingData} />}
        {showRepair && <WeaponRepair />}
      </Wrapper>
    </MantineProvider>
  );
};

export default App;

function Wrapper({ children }: { children: React.ReactNode }) {
  return isEnvBrowser() ? ( 
    <BackgroundImage w='100vw' h='100vh' style={{overflow:'hidden'}}
      src="https://i.imgur.com/kiK65kg.jpeg"
    >  
      {children}
    </BackgroundImage>
  ) : (
    <>{children}</>
  )
}
