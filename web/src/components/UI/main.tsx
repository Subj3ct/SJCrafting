import { 
  Text, 
  Transition, 
  Flex, 
  Card, 
  Stack, 
  Title, 
  Divider, 
  Group, 
  useMantineTheme,
  Grid,
  Image,
  Button,
  Badge,
  Progress,
  ScrollArea,
  TextInput,
  NumberInput,
  ActionIcon,
  Tooltip,
  Box
} from '@mantine/core';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import useAppVisibilityStore from '../../stores/appVisibilityStore';
import { 
  Search, 
  Clock, 
  User, 
  Package, 
  Percent, 
  Plus, 
  Minus, 
  Trash2,
  X,
  Hammer
} from 'lucide-react';
import { useState, useEffect } from 'react';
import { fetchNui } from '../../utils/fetchNui';

interface CraftingItem {
  name: string;
  label: string;
  description: string;
  image: string;
  time: number;
  requiredLevel: number;
  maxAmount: number;
  successChance: number;
  xpReward: number;
  recipe: Array<{
    item: string;
    label: string;
    amount: number;
  }>;
}

interface QueueItem {
  id: number;
  itemName: string;
  itemLabel: string;
  stationType: string;
  amount: number;
  timeRemaining: number;
  totalTime: number;
  successChance: number;
  xpReward: number;
  startTime: number;
}

interface CraftingData {
  level: number;
  xp: number;
  queue: QueueItem[];
  maxQueueSize: number;
}

interface UIProps {
  initialData?: {
    stationType: string;
    items: any[];
  };
}

export function UI({ initialData }: UIProps) {
  const theme = useMantineTheme();
  const { showApp, setVisibility } = useAppVisibilityStore();

  // State
  const [stationType, setStationType] = useState<string>('');
  const [items, setItems] = useState<CraftingItem[]>([]);
  const [selectedItem, setSelectedItem] = useState<CraftingItem | null>(null);
  const [craftingData, setCraftingData] = useState<CraftingData | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [craftAmount, setCraftAmount] = useState(1);
  const [loading, setLoading] = useState(false);

  // Filtered items based on search
  const filteredItems = items.filter((item: CraftingItem) => 
    item.label.toLowerCase().includes(searchQuery.toLowerCase()) ||
    item.name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  // Load crafting data
  const loadCraftingData = async () => {
    try {
      const response = await fetchNui<{success: boolean, data: CraftingData}>('getCraftingData');
      if (response && response.success) {
        setCraftingData(response.data);
      }
    } catch (error) {
      console.error('Failed to load crafting data:', error);
    }
  };

  // Add item to queue
  const addToQueue = async () => {
    if (!selectedItem || !stationType) return;
    
    setLoading(true);
    try {
      const response = await fetchNui<{success: boolean, message: string}>('addToQueue', {
        itemName: selectedItem.name,
        stationType: stationType,
        amount: craftAmount
      });
      
      if (response && response.success) {
        await loadCraftingData();
        setCraftAmount(1);
      } else {
        // Show error notification using ox_lib
        fetchNui('showNotification', {
          title: 'Error',
          description: response?.message || 'Unknown error occurred',
          type: 'error'
        });
      }
    } catch (error) {
      console.error('Failed to add to queue:', error);
      fetchNui('showNotification', {
        title: 'Error',
        description: 'Failed to add item to queue',
        type: 'error'
      });
    } finally {
      setLoading(false);
    }
  };

  // Cancel queue item
  const cancelQueueItem = async (itemId: number) => {
    try {
      const response = await fetchNui<{success: boolean, message?: string}>('cancelQueueItem', { queueIndex: itemId });
      if (response && response.success) {
        // Update queue locally without refreshing timer
        setCraftingData((prev: CraftingData | null) => {
          if (!prev) return prev;
          const updatedQueue = prev.queue.filter(item => item.id !== itemId);
          return {
            ...prev,
            queue: updatedQueue
          };
        });
      } else if (response && response.message) {
        // Show error message
        fetchNui('showNotification', {
          title: 'Error',
          description: response.message,
          type: 'error'
        });
        // If item not found, refresh queue data to sync with server
        if (response.message.includes('not found')) {
          await loadCraftingData();
        }
      }
    } catch (error) {
      console.error('Failed to cancel queue item:', error);
    }
  };

  // Format time
  const formatTime = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    
    if (hours > 0) {
      return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    } else {
      return `${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
  };

  // NUI Events
  useNuiEvent<{stationType: string, items: CraftingItem[]}>('OPEN_CRAFTING', (data) => {
    setStationType(data.stationType);
    setItems(data.items);
    setSearchQuery('');
    setCraftAmount(1);
    loadCraftingData();
    
    // Select first item by default
    if (data.items && data.items.length > 0) {
      setSelectedItem(data.items[0]);
    } else {
      setSelectedItem(null);
    }
  });

  // Handle visibility changes from App level
  useEffect(() => {
    if (!showApp) {
      setStationType('');
      setItems([]);
      setSelectedItem(null);
      setCraftingData(null);
      setSearchQuery('');
      setCraftAmount(1);
    }
  }, [showApp]);

  // Handle initial data from App level
  useEffect(() => {
    if (initialData) {
      setStationType(initialData.stationType);
      setItems(initialData.items);
      setSearchQuery('');
      setCraftAmount(1);
      loadCraftingData();
      
      // Select first item by default
      if (initialData.items && initialData.items.length > 0) {
        setSelectedItem(initialData.items[0]);
      } else {
        setSelectedItem(null);
      }
    }
  }, [initialData]);



  useNuiEvent<{level: number}>('LEVEL_UP', (data) => {
    if (craftingData) {
      setCraftingData({...craftingData, level: data.level});
    }
  });

  useNuiEvent<{itemName: string, amount: number, success: boolean}>('CRAFTING_COMPLETE', (data) => {
    // Refresh crafting data when item completes
    loadCraftingData();
  });

  // Notify when component is ready
  useEffect(() => {
    fetchNui('ready');
  }, []);

  // Handle ESC key to close UI
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && showApp) {
        fetchNui('hideApp');
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [showApp]);

  // Update queue timers and sync with server
  useEffect(() => {
    if (!craftingData?.queue.length) return;
    
    const interval = setInterval(() => {
      // Sync with server every 5 seconds to prevent desync
      if (Date.now() % 5000 < 1000) {
        loadCraftingData();
      } else {
        // Update first item timer locally
        setCraftingData((prev: CraftingData | null) => {
          if (!prev || !prev.queue.length) return prev;
          
          // Only update the first item in queue (FIFO)
          const updatedQueue = [...prev.queue];
          if (updatedQueue[0] && updatedQueue[0].timeRemaining > 0) {
            updatedQueue[0] = {
              ...updatedQueue[0],
              timeRemaining: Math.max(0, updatedQueue[0].timeRemaining - 1)
            };
          }
          
          return {
            ...prev,
            queue: updatedQueue
          };
        });
      }
    }, 1000);
    
    return () => clearInterval(interval);
  }, [craftingData?.queue.length]);

  // Auto-select first filtered item when search changes
  useEffect(() => {
    if (filteredItems.length > 0 && !selectedItem) {
      setSelectedItem(filteredItems[0]);
    } else if (filteredItems.length > 0 && selectedItem) {
      // Check if current selected item is still in filtered results
      const stillExists = filteredItems.some(item => item.name === selectedItem.name);
      if (!stillExists) {
        setSelectedItem(filteredItems[0]);
      }
    } else if (filteredItems.length === 0) {
      setSelectedItem(null);
    }
  }, [filteredItems, selectedItem]);
  
  return (
    <Transition mounted={showApp} transition="fade" duration={400} timingFunction="ease">
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
              {/* Left Panel - Item List */}
              <div style={{ 
                display: 'flex', 
                flexDirection: 'column', 
                height: '100%',
                overflow: 'hidden'
              }}>
                <Group justify="space-between" mb="xs" style={{ flexShrink: 0 }}>
                  <Title order={3} c="white">
                    {stationType.toUpperCase()} CRAFTING
                  </Title>
                  <Badge variant="light" color="blue">
                    LVL {craftingData?.level || 1}
                  </Badge>
                </Group>
                
                <TextInput
                  placeholder="Search items..."
                  leftSection={<Search size={16} />}
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
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
                    {filteredItems.map((item) => (
                        <Card
                          key={item.name}
                          p="sm"
                          style={{
                            backgroundColor: selectedItem?.name === item.name ? theme.colors.dark[6] : theme.colors.dark[7],
                            border: selectedItem?.name === item.name ? `1px solid ${theme.colors.blue[5]}` : `1px solid ${theme.colors.dark[5]}`,
                            cursor: 'pointer',
                            transition: 'all 0.2s ease'
                          }}
                          onClick={() => setSelectedItem(item)}
                        >
                          <Group gap="sm">
                            <Image
                              src={item.image}
                              width={40}
                              height={40}
                              fallbackSrc="https://via.placeholder.com/40"
                            />
                            <Box style={{ flex: 1 }}>
                              <Text size="sm" fw={500} c="white">
                                {item.label}
                              </Text>
                              <Text size="xs" c="dimmed">
                                Level {item.requiredLevel}
                              </Text>
                            </Box>
                          </Group>
                        </Card>
                      ))}
                                      </Stack>
                </div>
              </div>

              {/* Middle Panel - Item Details */}
              <div style={{ 
                display: 'flex', 
                flexDirection: 'column', 
                height: '100%',
                overflow: 'hidden'
              }}>
                <Stack h="100%" gap="sm">
                  {selectedItem ? (
                    <>
                      <Title order={3} c="white" mb="xs">
                        {selectedItem.label.toUpperCase()}
                      </Title>
                      
                      <Card p="sm" style={{ backgroundColor: theme.colors.dark[7] }}>
                        <Stack gap="xs">
              <Group gap="xs">
                            <Clock size={16} color={theme.colors.blue[4]} />
                            <Text size="sm" c="white">
                              {formatTime(selectedItem.time)} seconds
                            </Text>
              </Group>
              
                          <Group gap="xs">
                            <User size={16} color={theme.colors.green[4]} />
                            <Text size="sm" c="white">
                              Required Level: {selectedItem.requiredLevel}
                            </Text>
                          </Group>
                          
                          <Group gap="xs">
                            <Package size={16} color={theme.colors.yellow[4]} />
                            <Text size="sm" c="white">
                              Max Amount: {selectedItem.maxAmount}
              </Text>
                          </Group>
                          
                          <Group gap="xs">
                            <Percent size={16} color={theme.colors.orange[4]} />
                            <Text size="sm" c="white">
                              Success Chance: {selectedItem.successChance}%
                            </Text>
                          </Group>
                </Stack>
                      </Card>
                      
                      <Card p="sm" style={{ backgroundColor: theme.colors.dark[7] }}>
                        <Title order={4} c="white" mb="xs">
                          RECIPE
                        </Title>
                        <Stack gap="xs">
                          {selectedItem.recipe.length > 0 ? (
                            selectedItem.recipe.map((ingredient, index) => (
                              <Group key={index} gap="sm">
                                <Image
                                  src={`nui://ox_inventory/web/images/${ingredient.item}.png`}
                                  width={24}
                                  height={24}
                                  fallbackSrc="https://via.placeholder.com/24"
                                />
                                <Text size="sm" c="white">
                                  {ingredient.amount}x {ingredient.label || ingredient.item}
                                </Text>
                              </Group>
                            ))
                          ) : (
                            <Text size="sm" c="dimmed">
                              No ingredients needed
                            </Text>
                          )}
                </Stack>
                      </Card>
                      
                      <Group gap="xs" justify="center">
                        <ActionIcon
                          variant="light"
                          onClick={() => setCraftAmount(Math.max(1, craftAmount - 1))}
                          disabled={craftAmount <= 1}
                        >
                          <Minus size={16} />
                        </ActionIcon>
                        
                        <NumberInput
                          value={craftAmount}
                          onChange={(value) => setCraftAmount(typeof value === 'number' ? value : 1)}
                          min={1}
                          max={selectedItem.maxAmount}
                          style={{ width: 80 }}
                          styles={{
                            input: {
                              backgroundColor: theme.colors.dark[7],
                              borderColor: theme.colors.dark[5],
                              color: 'white',
                              textAlign: 'center'
                            }
                          }}
                        />
                        
                        <ActionIcon
                          variant="light"
                          onClick={() => setCraftAmount(Math.min(selectedItem.maxAmount, craftAmount + 1))}
                          disabled={craftAmount >= selectedItem.maxAmount}
                        >
                          <Plus size={16} />
                        </ActionIcon>
                      </Group>
                      
                      <Button
                        fullWidth
                        leftSection={<Hammer size={16} />}
                        onClick={addToQueue}
                        loading={loading}
                        disabled={!craftingData || craftingData.queue.length >= craftingData.maxQueueSize}
                      >
                        ADD TO CRAFTING QUEUE
                      </Button>
                    </>
                  ) : (
                    <Stack justify="center" align="center" h="100%">
                      <Text c="dimmed" ta="center">
                        Select an item to view details
                      </Text>
                    </Stack>
                  )}
                </Stack>
              </div>

              {/* Right Panel - Queue */}
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
                      CRAFTING QUEUE
                    </Title>
                    <ActionIcon
                      variant="light"
                      onClick={() => {
                        setVisibility(false);
                        fetchNui('hideApp');
                      }}
                    >
                      <X size={16} />
                    </ActionIcon>
                  </Group>
                  
                  <Stack gap="sm" style={{ paddingTop: '8px', paddingBottom: '8px' }}>
                    {craftingData?.queue.map((item, index) => (
                      <Card key={item.id} p="sm" style={{ backgroundColor: theme.colors.dark[7] }}>
                        <Stack gap="xs">
                          <Group justify="space-between">
                            <Text size="sm" fw={500} c="white">
                              {item.itemLabel} x{item.amount}
                            </Text>
                                                          <ActionIcon
                                variant="light"
                                color="red"
                                size="sm"
                                onClick={() => cancelQueueItem(item.id)}
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
                    
                    {(!craftingData?.queue || craftingData.queue.length === 0) && (
                      <Text c="dimmed" ta="center" mt="xl">
                        No items in queue
                      </Text>
                    )}
                  </Stack>
                  
                  <Text size="sm" c="dimmed" ta="center" style={{ flexShrink: 0, marginTop: '8px' }}>
                    Queue: {craftingData?.queue.length || 0}/{craftingData?.maxQueueSize || 0}
                  </Text>
                </div>
              </div>
            </div>
          </Card>
        </Flex>
      )}
    </Transition>
  );
}