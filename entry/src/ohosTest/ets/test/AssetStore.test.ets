import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { describe, it, expect } from '@ohos/hypium';

const PROBE_ALIAS = new util.TextEncoder().encodeInto('pixiv.test.asset.persistence-flag');
const SYNTHETIC_SECRET = new util.TextEncoder().encodeInto('synthetic-token-for-platform-regression');

function query(): asset.AssetMap {
  const attributes: asset.AssetMap = new Map();
  attributes.set(asset.Tag.ALIAS, PROBE_ALIAS);
  return attributes;
}

function attributes(): asset.AssetMap {
  const attributes = query();
  attributes.set(asset.Tag.SECRET, SYNTHETIC_SECRET);
  attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_UNLOCKED);
  attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
  return attributes;
}

export default function assetStoreTest(): void {
  describe('PixivAssetStoreRegression', () => {
    it('explicit_false_requires_permission_201', 0, async () => {
      const input = attributes();
      input.set(asset.Tag.IS_PERSISTENT, false);
      let code = 0;
      try { await asset.add(input); } catch (error) { code = (error as BusinessError).code; }
      try { await asset.remove(query()); } catch (_) { /* No test asset is expected when add fails. */ }
      expect(code).assertEqual(201);
    });

    it('omitted_flag_roundtrips_without_extra_permission', 0, async () => {
      try {
        await asset.add(attributes());
        const input = query();
        input.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
        const stored = await asset.query(input);
        expect(stored.length).assertEqual(1);
        const value = stored[0].get(asset.Tag.SECRET) as Uint8Array;
        expect(new util.TextDecoder().decodeToString(value)).assertEqual('synthetic-token-for-platform-regression');
      } finally {
        await asset.remove(query());
      }
    });
  });
}
