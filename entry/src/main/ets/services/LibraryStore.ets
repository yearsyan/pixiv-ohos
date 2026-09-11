import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Artwork } from '../models/PixivModels';

class LibraryStore {
  saved: Artwork[] = [];
  history: Artwork[] = [];
  searches: string[] = [];
  private store: preferences.Preferences | undefined = undefined;
  private writes: Promise<void> = Promise.resolve();
  private savedWrites: Promise<void> = Promise.resolve();

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.store = await preferences.getPreferences(context, { name: 'pixiv_library' });
    this.saved = JSON.parse(await this.store.get('saved', '[]') as string) as Artwork[];
    this.history = JSON.parse(await this.store.get('history', '[]') as string) as Artwork[];
    this.searches = JSON.parse(await this.store.get('searches', '[]') as string) as string[];
  }

  isSaved(id: number): boolean { return this.saved.some((work: Artwork) => work.id === id); }

  private persist(key: string, value: string): Promise<void> {
    const write = this.writes.catch(() => {}).then(async () => {
      if (!this.store) { throw new Error('Local library is unavailable'); }
      await this.store.put(key, value);
      await this.store.flush();
    });
    this.writes = write;
    return write;
  }

  async toggleSaved(artwork: Artwork): Promise<boolean> {
    const update = this.savedWrites.catch(() => {}).then(async (): Promise<boolean> => {
      const exists = this.isSaved(artwork.id);
      const next = exists ? this.saved.filter((work: Artwork) => work.id !== artwork.id) : [artwork, ...this.saved];
      await this.persist('saved', JSON.stringify(next));
      this.saved = next;
      return !exists;
    });
    this.savedWrites = update.then(() => {}, () => {});
    return update;
  }

  async recordView(artwork: Artwork): Promise<void> {
    this.history = [artwork, ...this.history.filter((work: Artwork) => work.id !== artwork.id)].slice(0, 150);
    await this.persist('history', JSON.stringify(this.history));
  }

  async recordSearch(word: string): Promise<void> {
    if (!word.trim()) { return; }
    this.searches = [word, ...this.searches.filter((item: string) => item !== word)].slice(0, 12);
    await this.persist('searches', JSON.stringify(this.searches));
  }

  async clearHistory(): Promise<void> { this.history = []; await this.persist('history', '[]'); }
  async clearSearches(): Promise<void> { this.searches = []; await this.persist('searches', '[]'); }
}

export const libraryStore = new LibraryStore();
