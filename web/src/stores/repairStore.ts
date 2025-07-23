import { create } from "zustand";
import { isEnvBrowser } from "../utils/misc";

type RepairState = {
	showRepair: boolean;
	repairData: {
		stationType: string;
		items: any[];
	} | null;
	setRepairVisibility: (boolean: boolean) => void;
	setRepairData: (data: { stationType: string; items: any[] } | null) => void;
	openRepair: () => void;
	closeRepair: () => void;
	toggleRepair: () => void;
};

const useRepairStore = create<RepairState>((set) => ({
	showRepair: false,
	repairData: null,
	setRepairVisibility: (boolean: boolean) => {
		set({ showRepair: boolean });
	},
	setRepairData: (data: { stationType: string; items: any[] } | null) => {
		set({ repairData: data });
	},
	openRepair: () => {
		set({ showRepair: true });
	},
	closeRepair: () => {
		set({ showRepair: false });
	},
	toggleRepair: () => set((state) => ({ showRepair: !state.showRepair })),
}));

export default useRepairStore; 