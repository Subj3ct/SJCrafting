import React, { useState, useEffect } from 'react';
import { 
  Container, 
  Grid, 
  Card, 
  Text, 
  Button, 
  Progress, 
  Group, 
  Badge, 
  Stack, 
  ActionIcon,
  Transition,
  Flex,
  Title,
  ScrollArea,
  TextInput,
  Divider,
  useMantineTheme,
  Image,
  Box
} from '@mantine/core';
import { Wrench, Trash2, Search, Clock, User, Percent, X } from 'lucide-react';
import { fetchNui } from '../../utils/fetchNui';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import useRepairStore from '../../stores/repairStore';

interface WeaponRepairItem {
  name: string;
  label: string;
  slot: number;
  durability: number;
  time: number;
  requiredLevel: number;
  successChance: number;
  materials: Array<{
    item: string;
    label: string;
    amount: number;
  }>;
}

interface RepairQueueItem {
  id: number;
  itemName: string;
  itemLabel: string;
  timeRemaining: number;
  totalTime: number;
  successChance: number;
}

const WeaponRepair: React.FC = () => {
  const theme = useMantineTheme();
  const { showRepair, setRepairVisibility, setRepairData, repairData } = useRepairStore();
  const [repairableWeapons, setRepairableWeapons] = useState<WeaponRepairItem[]>([]);
  const [selectedWeapon, setSelectedWeapon] = useState<WeaponRepairItem | null>(null);
  const [repairQueue, setRepairQueue] = useState<RepairQueueItem[]>([]);
  const [searchTerm, setSearchTerm] = useState('');

  // Filtered weapons based on search
  const filteredWeapons = repairableWeapons.filter(weapon =>
    weapon.label.toLowerCase().includes(searchTerm.toLowerCase()) ||
    weapon.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  // Update repairable weapons when repair data changes
  useEffect(() => {
    if (repairData && repairData.items) {
      setRepairableWeapons(repairData.items);
      setSelectedWeapon(null);
      loadRepairQueue();
    }
  }, [repairData]);

  // Auto-select first filtered item when search changes
  useEffect(() => {
    if (filteredWeapons.length > 0 && !selectedWeapon) {
      setSelectedWeapon(filteredWeapons[0]);
    } else if (filteredWeapons.length > 0 && selectedWeapon) {
      // Check if current selected weapon is still in filtered results
      const stillExists = filteredWeapons.some(weapon => weapon.name === selectedWeapon.name);
      if (!stillExists) {
        setSelectedWeapon(filteredWeapons[0]);
      }
    } else if (filteredWeapons.length === 0) {
      setSelectedWeapon(null);
    }
  }, [filteredWeapons, selectedWeapon]);

  const loadRepairQueue = async () => {
    try {
      const queue = await fetchNui('getRepairQueue', {});
      setRepairQueue(queue || []);
    } catch (error) {
      console.error('Failed to load repair queue:', error);
    }
  };

  const addToRepairQueue = async () => {
    if (!selectedWeapon) return;

    try {
      const response = await fetchNui('addToRepairQueue', {
        itemName: selectedWeapon.name,
        slot: selectedWeapon.slot,
        stationType: 'weapon'
      });

      if (response && response.success) {
        // Refresh queue and weapons list
        loadRepairQueue();
        fetchNui('getRepairableItems', { stationType: 'weapon' }).then((items) => {
          setRepairableWeapons(items || []);
        });
        setSelectedWeapon(null);
      } else {
        // Show error notification
        fetchNui('showNotification', {
          title: 'Error',
          description: response?.message || 'Failed to add to repair queue',
          type: 'error'
        });
      }
    } catch (error) {
      console.error('Failed to add to repair queue:', error);
    }
  };

  const cancelRepairItem = async (itemId: number) => {
    try {
      const response = await fetchNui('cancelRepairQueueItem', { queueIndex: itemId });
      if (response && response.success) {
        loadRepairQueue();
      }
    } catch (error) {
      console.error('Failed to cancel repair item:', error);
    }
  };

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  // Update queue timers and sync with server
  useEffect(() => {
    if (!repairQueue.length) return;
    
    const interval = setInterval(() => {
      // Sync with server every 5 seconds to prevent desync
      if (Date.now() % 5000 < 1000) {
        loadRepairQueue();
      } else {
        // Update first item timer locally
        setRepairQueue((prev: RepairQueueItem[]) => {
          if (!prev || !prev.length) return prev;
          
          // Only update the first item in queue (FIFO)
          const updatedQueue = [...prev];
          if (updatedQueue[0] && updatedQueue[0].timeRemaining > 0) {
            updatedQueue[0] = {
              ...updatedQueue[0],
              timeRemaining: Math.max(0, updatedQueue[0].timeRemaining - 1)
            };
          }
          
          return updatedQueue;
        });
      }
    }, 1000);
    
    return () => clearInterval(interval);
  }, [repairQueue.length]);

  // Listen for NUI events
  useNuiEvent('CLOSE_REPAIR', () => {
    setRepairVisibility(false);
    setRepairData(null);
    setRepairableWeapons([]);
    setSelectedWeapon(null);
    setRepairQueue([]);
  });

  useNuiEvent<{itemName: string, success: boolean}>('REPAIR_COMPLETE', (data) => {
    // Refresh repair data when item completes
    loadRepairQueue();
    // Refresh the repairable weapons list
    fetchNui('getRepairableItems', { stationType: 'weapon' }).then((items) => {
      setRepairableWeapons(items || []);
    });
  });

  useNuiEvent<{items: WeaponRepairItem[]}>('UPDATE_REPAIRABLE_ITEMS', (data) => {
    // Update the repairable weapons list when items are added/removed from queue
    setRepairableWeapons(data.items || []);
    setSelectedWeapon(null);
  });

  // Handle ESC key to close UI
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && showRepair) {
        fetchNui('closeRepair', {});
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [showRepair]);

  if (!showRepair) return null;

  return (
    <Transition mounted={showRepair} transition="fade" duration={400} timingFunction="ease">
      {(transStyles: any) => (
        <Flex
          pos="fixed"
          w="100vw"
          h="100vh"
          style={{
            pointerEvents: 'none',
            justifyContent: 'center',
            alignItems: 'center',
            padding: '20px',
          }}
        >
          <Card
            p="xl"
            style={{
              ...transStyles,
              backgroundColor: theme.colors.dark[8],
              borderRadius: theme.radius.md,
              maxWidth: '1200px',
              width: '100%',
              height: '600px',
              pointerEvents: 'auto',
            }}
          >
            <div style={{ 
              display: 'grid', 
              gridTemplateColumns: '1fr 1fr 1fr', 
              gap: '16px', 
              height: '100%',
              overflow: 'hidden'
            }}>
              {/* Left Panel - Weapon List */}
              <div style={{ 
                display: 'flex', 
                flexDirection: 'column', 
                height: '100%',
                overflow: 'hidden'
              }}>
                <Group justify="space-between" mb="xs" style={{ flexShrink: 0 }}>
                  <Title order={3} c="white">
                    WEAPON REPAIR
                  </Title>
                  <Badge variant="light" color="red">
                    REPAIR
                  </Badge>
                </Group>
                
                <TextInput
                  placeholder="Search weapons..."
                  leftSection={<Search size={16} />}
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  styles={{
                    input: {
                      backgroundColor: theme.colors.dark[7],
                      borderColor: theme.colors.dark[5],
                      color: 'white'
                    }
                  }}
                  style={{ flexShrink: 0, marginBottom: '8px' }}
                />

                <div style={{ 
                  flex: 1, 
                  overflowY: 'auto',
                  overflowX: 'hidden',
                  paddingRight: '8px'
                }}>
                  <Stack gap="xs" style={{ paddingTop: '8px', paddingBottom: '8px' }}>
                    {filteredWeapons.map((weapon) => (
                      <Card
                        key={weapon.slot}
                        p="sm"
                        style={{
                          backgroundColor: selectedWeapon?.slot === weapon.slot ? theme.colors.dark[6] : theme.colors.dark[7],
                          border: selectedWeapon?.slot === weapon.slot ? `1px solid ${theme.colors.blue[5]}` : `1px solid ${theme.colors.dark[5]}`,
                          cursor: 'pointer',
                          transition: 'all 0.2s ease'
                        }}
                        onClick={() => setSelectedWeapon(weapon)}
                      >
                        <Group gap="sm">
                          <Image
                            src={`nui://ox_inventory/web/images/${weapon.name}.png`}
                            width={40}
                            height={40}
                            fallbackSrc="https://via.placeholder.com/40"
                          />
                          <Box style={{ flex: 1 }}>
                            <Text size="sm" fw={500} c="white">
                              {weapon.label}
                            </Text>
                            <Text size="xs" c="dimmed">
                              Level {weapon.requiredLevel}
                            </Text>
                          </Box>
                          <Badge color={weapon.durability < 30 ? 'red' : weapon.durability < 60 ? 'yellow' : 'green'}>
                            {weapon.durability.toFixed(1)}%
                          </Badge>
                        </Group>
                      </Card>
                    ))}
                  </Stack>
                </div>
              </div>

              {/* Middle Panel - Weapon Details */}
              <div style={{ 
                display: 'flex', 
                flexDirection: 'column', 
                height: '100%',
                overflow: 'hidden'
              }}>
                <Stack h="100%" gap="sm">
                  {selectedWeapon ? (
                    <>
                      <Title order={3} c="white" mb="xs">
                        {selectedWeapon.label.toUpperCase()}
                      </Title>
                      
                      <Card p="sm" style={{ backgroundColor: theme.colors.dark[7] }}>
                        <Stack gap="xs">
                          <Group gap="xs">
                            <Clock size={16} color={theme.colors.blue[4]} />
                            <Text size="sm" c="white">
                              {formatTime(selectedWeapon.time)} seconds
                            </Text>
                          </Group>
                          
                          <Group gap="xs">
                            <User size={16} color={theme.colors.green[4]} />
                            <Text size="sm" c="white">
                              Required Level: {selectedWeapon.requiredLevel}
                            </Text>
                          </Group>
                          
                          <Group gap="xs">
                            <Percent size={16} color={theme.colors.orange[4]} />
                            <Text size="sm" c="white">
                              Success Chance: {selectedWeapon.successChance}%
                            </Text>
                          </Group>
                        </Stack>
                      </Card>
                      
                      <Card p="sm" style={{ backgroundColor: theme.colors.dark[7] }}>
                        <Title order={4} c="white" mb="xs">
                          RECIPE
                        </Title>
                        <Stack gap="xs">
                          {selectedWeapon.materials.length > 0 ? (
                            selectedWeapon.materials.map((material, index) => (
                              <Group key={index} gap="sm">
                                <Image
                                  src={`nui://ox_inventory/web/images/${material.item}.png`}
                                  width={24}
                                  height={24}
                                  fallbackSrc="https://via.placeholder.com/24"
                                />
                                <Text size="sm" c="white">
                                  {material.amount}x {material.label || material.item}
                                </Text>
                              </Group>
                            ))
                          ) : (
                            <Text size="sm" c="dimmed">
                              No materials needed
                            </Text>
                          )}
                        </Stack>
                      </Card>
                      
                      <Button
                        fullWidth
                        leftSection={<Wrench size={16} />}
                        onClick={addToRepairQueue}
                        style={{
                          backgroundColor: theme.colors.blue[6],
                          color: 'white'
                        }}
                      >
                        ADD TO REPAIR QUEUE
                      </Button>
                    </>
                  ) : (
                    <Stack justify="center" align="center" h="100%">
                      <Text c="dimmed" ta="center">
                        Select a weapon to repair
                      </Text>
                    </Stack>
                  )}
                </Stack>
              </div>

              {/* Right Panel - Repair Queue */}
              <div style={{ 
                display: 'flex', 
                flexDirection: 'column', 
                height: '100%',
                overflow: 'hidden'
              }}>
                <div style={{ 
                  height: '100%', 
                  overflowY: 'auto',
                  overflowX: 'hidden',
                  paddingRight: '8px'
                }}>
                  <Group justify="space-between" mb="xs" style={{ flexShrink: 0 }}>
                    <Title order={3} c="white">
                      REPAIR QUEUE
                    </Title>
                    <ActionIcon
                      variant="light"
                      onClick={() => {
                        fetchNui('closeRepair', {});
                      }}
                    >
                      <X size={16} />
                    </ActionIcon>
                  </Group>
                  
                  <Stack gap="sm" style={{ paddingTop: '8px', paddingBottom: '8px' }}>
                    {repairQueue.map((item) => (
                      <Card key={item.id} p="sm" style={{ backgroundColor: theme.colors.dark[7] }}>
                        <Stack gap="xs">
                          <Group justify="space-between">
                            <Text size="sm" fw={500} c="white">
                              {item.itemLabel}
                            </Text>
                            <ActionIcon
                              variant="light"
                              color="red"
                              size="sm"
                              onClick={() => cancelRepairItem(item.id)}
                            >
                              <Trash2 size={14} />
                            </ActionIcon>
                          </Group>
                          
                          <Progress
                            value={((item.totalTime - item.timeRemaining) / item.totalTime) * 100}
                            color="blue"
                            size="sm"
                          />
                          
                          <Text size="xs" c="dimmed">
                            {formatTime(item.timeRemaining)} remaining
                          </Text>
                        </Stack>
                      </Card>
                    ))}
                    
                    {(!repairQueue || repairQueue.length === 0) && (
                      <Text c="dimmed" ta="center" mt="xl">
                        No items in repair queue
                      </Text>
                    )}
                  </Stack>
                  
                  <Text size="sm" c="dimmed" ta="center" style={{ flexShrink: 0, marginTop: '8px' }}>
                    Queue: {repairQueue.length}/10
                  </Text>
                </div>
              </div>
            </div>
          </Card>
        </Flex>
      )}
    </Transition>
  );
};

export default WeaponRepair; 